const core = require("@actions/core");

const author = process.env.AUTHOR;
const commits = JSON.parse(process.env.COMMITS);

const filtered = commits
    .filter(f => f.author.username === author)
    .map(commit => {
        return {
            id: commit.id,
            message: commit.message
        }
    });

core.setOutput("commits", JSON.stringify(filtered));