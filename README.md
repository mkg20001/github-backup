# github-backup
Backup all your GitHub repos.

# Usage
`bash github-backup.sh <username> [stagit]`

**Note: Stagit requires `libgit2-dev` to compile**

# Result

```
USER
├── USER_repos.json
├── repos
│   └── (bare repositories)
├── stagit
│   ├── index.html
│   └── (stagit directories)
└── stagit.cache
    └── (stagit cache files)
```
