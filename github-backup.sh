#!/bin/bash

usage() {
  echo
  echo "Usage: $0 <username> [stagit] [org]"
  echo
  echo " stagit        - Generate static Git Sites using stagit (requires 'libgit2-dev')"
  echo " org           - <username> is a GitHub organization"
  echo " trash         - Move old repos into <username>.trash"
  echo " extended      - Allow extended api calls to get information about forks (you run out of quota soon) (will be saved in USER/repos/REPO.json)"
  echo " token=<token> - Use an Authorization Token"
  echo " -h            - This help text."
  echo
}

parse_options() {
  set -- "$@"
  local ARGN=$#
  while [ "$ARGN" -ne 0 ]
  do
    if [ -z "$user" ]; then
      user="$1"
    else
      case $1 in
        -h) usage
            exit 0
        ;;
        stagit) isstagit=true
        ;;
        org) isorg=true
        ;;
        extended) allowextendedinfo=true
        ;;
        token=*) token=${1/"token="/""};hastoken=true
        ;;
        trash) istrashmode=true
        ;;
        ?*) echo "ERROR: Unknown option."
            usage
            exit 1
        ;;
      esac
    fi
    shift 1
    ARGN=$((ARGN-1))
  done
  if [ -z "$user" ]; then
    usage
    exit 1
  fi
}

find_in_json() {
  line=$(echo "$prejson" | grep "^\\[$2\\]")
  if [ -z "$line" ]; then
    echo "WARN: Nothing found for $2" 1>&2
  else
    IFS="$tab" read -ra find <<< "$line"
    echo "${find[1]}"
  fi
}

no_quote() {
  read _in
  temp="${_in%\"}"
  temp="${temp#\"}"
  echo "$temp"
}

repo_get() {
  v=$(array_find $repo_num $1)
  e=$"$v"
  eval "$2=\"$e\""
}

array_find() {
  find_in_json $userr "$1,\"$2\"" | no_quote
}

log() {
  echo " => $@"
}
log2() {
  q=${@/"$1"/""}
  echo "    => [$1] $q"
}
log3() {
  echo "    => $@"
}

exit_code() {
  if [ $1 -ne 0 ]; then
    echo "ERROR: $2!"
    exit $1
  fi
}

git_pipe() {
  git log --all -q
  git tag
}

git_ver() {
  git_pipe | sha256sum
}

isstagit=false
istrashmode=false
isorg=false
allowextendedinfo=false
hastoken=false
token=""

parse_options "$@"

tab=$(printf '\t')
user=$1
main=$(dirname $(readlink -f $0))
mkdir -p $1/repos
cd $1
userb=$PWD
userr=$userb/repo.json

log "GitHub Backup.sh v1"

if ! [ -e "$main/stagit" ]; then
  git submodule init
  exit_code $? "Could not init the submodules"
  git submodule update
  exit_code $? "Could not update the submodules"
fi

if $isstagit; then
  if ! [ -e "$main/stagit/stagit" ]; then
    log "Compile stagit"
    make -C $main/stagit
    exit_code $? "Could not compile stagit (did you install 'libgit2-dev' ?)"
  fi
  isstagit=true
  stagit="$main/stagit/stagit"
  mkdir -p $userb/stagit
  mkdir -p $userb/stagit.cache
  log3 "'stagit' enabled"
fi

if ! [ -e "$main/node_modules" ]; then
  log3 "node_modules does not exist"
  log3 "Running npm i"
  npm i
  exit_code $? "npm i failed"
fi

log "Backup user $user"

if ! [ -e "repo.json" ]; then
  if [ -e "${user}_repos.json" ]; then
    mv "${user}_repos.json" "${user}_repos.json.bak"
  fi
  log3 "GET /users/$user/repos"
  node $main/repos.js "$user" "$isorg"
  exit_code $? "Failed to GET /users/$user/repos"
fi

prejson=$(cat $userr | bash $main/node_modules/.bin/JSON.sh)

seq=$(echo "$prejson" | grep -o "\\[[0-9][0-9]*\\]" | grep -o "[0-9]*")
length=$(echo "$seq" | tail -n 1)
let length2=$length+1
log "Backup $length2 repo(s)"
repos=""
repos_f=""

for i in $seq; do
  repo_num=$i
  repo_get name repo
  let i2=$i+1
  log "Backup $repo ($i2/$length2)"
  repo_get full_name url
  repo_get clone_url fullurl
  repo_get fork isfork
  repo_get description desc
  repos="$repos $repo"
  repofull="$userb/repos/$repo"
  repos_f="$repos_f $repofull"
  cd repos

  needupdate=false

  if [ -e "$repo" ]; then
    log2 "update" "$fullurl"
    cd $repo
    pre_com=$(git_ver)
    exit_code $? "Failed to update $fullurl"

    git fetch --all
    exit_code $? "Failed to update $fullurl"

    post_com=$(git_ver)
    exit_code $? "Failed to update $fullurl"

    [ "$post_com" != "$pre_com" ] && needupdate=true
  else
    log2 "mirror" "$fullurl"
    git clone --bare --mirror "$fullurl" "$repo"
    exit_code $? "Failed to clone $fullurl"
    needupdate=true
  fi

  cd $repofull
  ver=$(git_ver)

  cd $repofull
  log3 "Update information (extended $allowextendedinfo)"
  echo "$desc" > description
  echo "$fullurl" > url
  echo "$user" > owner

  if $allowextendedinfo; then
    repo_get url repourl
    wget -qq "$repourl" -O $userb/repos/$repo.json
    exit_code $? "Could not get information from $url (Quota exceed?)"
  fi

  if [ -e "$userb/repos/$repo.json" ]; then
    prejson_="$prejson"
    repoinfo=$(cat $userb/repos/$repo.json)
    prejson=$(echo "$repoinfo" | bash $main/node_modules/.bin/JSON.sh)

    if $isfork; then
      find_in_json "" '"source","clone_url"' | no_quote > fork_source
      find_in_json "" '"parent","clone_url"' | no_quote > fork_parent
    fi

    prejson="$prejson_"
  else
    if $isfork; then
      echo "[FORK] $desc" > description
    fi
  fi

  stafolder="$userb/stagit/$repo"
  stacache="$userb/stagit.cache/$repo"

  staver=$(cat $stacache.ver 2> /dev/null)
  $isstagit && [ ! -e $stafolder ] && needupdate=true
  $isstagit && [ "$staver" != "$ver" ] && needupdate=true

  if $needupdate; then
    if $isstagit; then
      log3 "Update stagit"
      mkdir -p $stafolder
      cd $stafolder
      $stagit -c $stacache $repofull
      exit_code $? "Stagit failed"
      echo "$ver" > $stacache.ver
    fi
  else
    log3 "Skip updating"
  fi

  log3 "DONE!"
  cd $userb
done

if $isstagit; then
  log "Update stagit index"
  cd $userb/stagit
  ${stagit}-index $repos_f > ./index.html
  cd $userb
fi

log "Cleanup"

if $istrashmode; then
  trash="$userb/trash"
  log "Moving old repos to $trash"
  mkdir -p "$trash"
  for r in repos stagit stagit.cache; do
    for f in $(dir -w 1 "$userb/$r"); do
      if [ -d "$userb/$r/$f" ]; then
        dodel=true
        for rr in $repos; do
          if [ "$rr" == "$f" ]; then
            dodel=false
          fi
        done
        if $dodel; then
          log2 "trash" "$r for $f"
          mv "$userb/$r/$f" "$trash/$f.$r"
        fi
      fi
    done
  done
fi

cd $userb

mv repo.json ${user}_repos.json
if [ -e "${user}_repos.json.bak" ]; then
  rm "${user}_repos.json.bak"
fi

log "DONE!"
