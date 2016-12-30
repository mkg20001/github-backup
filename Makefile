install:
	npm i -g
test:
	mkdir -p backup
	cd backup;$(PWD)/github-backup.sh octocat stagit
	cd backup;$(PWD)/github-backup.sh os-loader stagit org
