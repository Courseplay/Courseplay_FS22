const { execSync } = require("child_process");
const { readFileSync, writeFileSync } = require("fs");
const regionNamesInEnglish = new Intl.DisplayNames(["en"], { type: "language" });
const translationFileNameRegexp = /translation_(.{2})\.xml/;

function getUserTag(name) {
    return `@${name}`;
}

function readContributors() {
    const data = readFileSync("./contributors.json", "utf-8");
    return JSON.parse(data);
}

function writeContributors(contributors) {
    writeFileSync("./contributors.json", JSON.stringify(contributors), "utf-8");
}

function getContributorList() {
    return readContributors().main.sort().map(getUserTag);
}

function getTranslatorContributorList() {
    const translators = readContributors().translators;
    return Object.keys(translators).reduce((prev, curr) => {
        prev.push({
            language: curr,
            languageTranslated: regionNamesInEnglish.of(curr),
            translators: translators[curr]
        });
        return prev;
    }, []);
}

function compareTranslatedLanguages(a, b) {
    if (a.languageTranslated < b.languageTranslated) {
        return -1;
    }
    if (a.languageTranslated > b.languageTranslated) {
        return 1;
    }
    return 0;
}

function createContributorsFile() {
    let data = readFileSync("contributors-template.md", "utf-8");
    data = data.replace("[[main]]", getContributorList()
        .map(m => `* ${m}`)
        .join("\n"));
    data = data.replace("[[translators]]", getTranslatorContributorList()
        .sort(compareTranslatedLanguages)
        .map(m => `* ${regionNamesInEnglish.of(m.language)}: ${m.translators.map(getUserTag).sort().join(", ")}`)
        .join("\n"));
    writeFileSync("../../../../Contributors.md", data, "utf-8");
}

function updateInternalContributors(user, langs) {
    const contributors = readContributors();
    for (const lang of langs) {
        if (!contributors.translators[lang]) {
            contributors.translators[lang] = [];
        }
        if (!contributors.translators[lang].find(item => item === user)) {
            contributors.translators[lang].push(user);
        }
    }
    writeContributors(contributors);
}

function getLanguagesFromCommitFiles(sha) {
    const output = execSync(`git diff-tree --no-commit-id --name-only -r ${sha}`);
    const translationFiles = output
        .toString("utf-8")
        .split("\n")
        .filter(item => item.startsWith("translations/"));
    return translationFiles
        .map(m => {
            const match = m.match(translationFileNameRegexp);
            if (match && match[1]) {
                return match[1];
            }
            return null;
        })
        .filter(f => f !== null);
}

// Script start
const args = process.argv.slice(2);
const user = args[0];
const sha = args[1];

const langs = getLanguagesFromCommitFiles(sha);
updateInternalContributors(user, langs);
createContributorsFile();