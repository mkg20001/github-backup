const isOrg = process.argv[3]=="true"
const githubRepositories = isOrg?require("./org-repos.js"):require('github-repositories')
const fs = require("fs")

githubRepositories(process.argv[2]).then(data => {
    fs.writeFileSync(process.cwd()+"/repo.json",JSON.stringify(data,{spaces:2}))
}).catch(err => {
  console.error("ERROR: "+err.toString())
  process.exit(2)
});
