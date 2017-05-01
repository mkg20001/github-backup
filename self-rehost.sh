#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <username>"
  exit 2
fi

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

main=$(dirname $(readlink -f $0))
stamain="$main/stagit"
stagit="$stamain/stagit"

usage() {
  echo
  echo "Usage: $0 <username> [stagit] [org]"
  echo
  echo " domain=<domain> - Domain used for hosting"
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

domain="example.com"

parse_options "$@"

log "GitHub Self-Rehost.sh v1"

userb="$PWD/$1"
userR="$userb/repos"
userS="$userb/stagit"
userC="$userb/stagit.cache"
out="$userb-rehost"
mkdir -p $out

if ! [ -e "$userb" ]; then
  echo "$userb not found"
  echo "Run $ github-backup.sh $user stagit"
  exit 2
fi
if ! [ -e "$userS" ]; then
  echo "$users not found"
  echo "Run $ github-backup.sh $user stagit"
  exit 2
fi

rm -rf $out
mkdir -p $out

log "Copy resources"
cp $stamain/style.css $out/style.css

cp $stamain/logo.png $out/avatar.png
cp $out/avatar.png $out/favicon.png
cp $out/avatar.png $out/logo.png


log "Copy files into destination"

cd $out

repos=$(dir -w 1 $userR)
repos_g=""
for repo in $repos; do
  log "Copy $repo"
  if ! [ -e "$userS/$repo" ]; then
    echo "WARN: stagit folder for $repo not found"
  fi
  log3 "Copying bare repo"
  cp -rp $userR/$repo $out/$repo.git
  log3 "Copying HTML"
  cp -rp $userS/$repo $out/$repo
  log3 "Copying stagit cache"
  cp -rp $userC/$repo $out/$repo.cache

  newurl="https://$domain/$repo.git"
  log3 "Update url to $newurl"
  echo "$newurl" > $out/$repo.git/url
  cd $out/$repo
  log3 "Copy resources"
  for r in style.css favicon.png; do
    ln -s ../$r $out/$repo/$r
  done
  cp $out/logo.png $out/$repo/logo.png

  log3 "Run stagit to apply changes"
  $stagit -c $out/$repo.cache $out/$repo.git
  exit_code $? "stagit failed"


  repos_g="$repos_g $repo.git"
  cd $out
done

cd $out

log "Update index"

stagit-index $repos_g > index.html
exit_code $? "stagit-index failed"
