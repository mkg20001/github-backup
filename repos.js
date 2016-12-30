const isOrg = process.argv[3]=="true"
const githubRepositories = isOrg?require("./org-repos.js"):require('github-repositories')
const jsonfile = require('jsonfile')

jsonfile.spaces = 2

githubRepositories(process.argv[2]).then(data => {
  jsonfile.writeFileSync(process.cwd()+"/repo.json",data)
}).catch(err => {
  console.error("ERROR: "+err.toString())
  process.exit(2)
});
