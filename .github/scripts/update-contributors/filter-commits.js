const author = process.env.AUTHOR;
const commits = JSON.parse(process.env.COMMITS);

const filtered = commits
    .filter(f => f)
    .map(commit => {
        return {
            id: commit.id,
            message: commit.message
        }
    });
console.log(`::set-output name=commits::${JSON.stringify(filtered)}`);