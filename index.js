const githubRepositories = require('github-repositories');
const fs = require("fs")

githubRepositories(process.argv[2]).then(data => {
    //console.log(data);
    //=> [{id: 29258368, name: 'animal-sounds', full_name: 'kevva/animal-sounds', ...}, ...]
    fs.writeFileSync(process.cwd()+"/repo.json",JSON.stringify(data,{spaces:2}))
}).catch(err => {
  console.error("A wild error in it's natural habitat: "+err.toString())
});
