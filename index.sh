#!/bin/bash

#set -o pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <user>"
  exit 2
fi

. JSON.sh

tab=$(printf '\t')
user=$1
main=$PWD
mkdir -p $1/repos
cd $1
userb=$PWD
userr=$userb/repo.json

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
    echo "$2!"
    exit $1
  fi
}

log "Backup user $user"

if ! [ -e "repo.json" ]; then
  if [ -e "${user}_repos.json" ]; then
    mv "${user}_repos.json" "${user}_repos.json.bak"
  fi
  log3 "GET /users/$user/repos"
  node $main/index.js "$user"
  exit_code $? "Failed to GET /users/$user/repos"
fi

isstagit=false

if [ "$2" == "stagit" ]; then
  if ! [ -e "$main/stagit" ]; then
    git submodule init
    exit_code $? "Could not init the submodules"
    git submodule update
    exit_code $? "Could not update the submodules"
  fi
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

prejson=$(cat $userr | tokenize | parse)

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
  repo_get fork isfork
  repo_get description desc
  repos="$repos $repo"
  repofull="$userb/repos/$repo"
  fullurl="https://github.com/$url.git"
  repos_f="$repos_f $repofull"
  cd repos
  if [ -e "$repo" ]; then
    log2 "update" "$fullurl"
    cd $repo
    git fetch --all # 2>&1 | sed 's/^/       => /' #"$fullurl"
    exit_code $? "Failed to update $fullurl"
  else
    log2 "mirror" "$fullurl"
    git clone --bare --mirror "$fullurl" "$repo" # 2>&1 | sed 's/^/       => /'
    exit_code $? "Failed to clone $fullurl"
  fi
  cd $repofull
  log3 "Update description"
  echo "$desc" > description
  if $isstagit; then
    stafolder="$userb/stagit/$repo"
    stacache="$userb/stagit.cache/$repo"
    log3 "Update stagit"
    mkdir -p $stafolder
    cd $stafolder
    $stagit -c $stacache $repofull
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

cd $userb

mv repo.json ${user}_repos.json
if [ -e "${user}_repos.json.bak" ]; then
  rm "${user}_repos.json.bak"
fi

log "DONE!"
