const { readFileSync, writeFileSync } = require("fs");
const translationFileNameRegexp = /translation_(.{2})\.xml/;

function getUserTag(name) {
    return `[${name}](/${name})`;
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
    const contribs = readContributors();
    return Object.keys(contribs.translators).reduce((prev, curr) => {
        if (contribs.translators[curr].length > 0) {
            prev.push({
                language: curr,
                languageTranslated: contribs.languages[curr],
                translators: contribs.translators[curr]
            });
        }
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
        .map(m => `* ${m.languageTranslated}: ${m.translators.map(getUserTag).sort().join(", ")}`)
        .join("\n"));
    writeFileSync("../../../Contributors.md", data, "utf-8");
}

function updateInternalContributors(user, langs) {
    const contributors = readContributors();
    for (const lang of langs) {
        if (!contributors.translators[lang]) {
            contributors.translators[lang] = [];
        }
        if (!contributors.translators[lang].find(item => item === user) &&
            !contributors.main.find(item => item === user)) {
            contributors.translators[lang].push(user);
            console.log(`Adding contributor ${user} to language ${lang}`)
        }
    }
    writeContributors(contributors);
}

function getLanguagesFromCommitFiles(files) {
    const translationFiles = files.filter(item => item.startsWith("translations/"));
    console.log("Changed translation files:");
    console.log(translationFiles);
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
const files = args.slice(1);

const langs = getLanguagesFromCommitFiles(files);
updateInternalContributors(user, langs);
createContributorsFile();