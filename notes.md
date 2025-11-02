Gemini 2.0 Flash was very good at writing incorrect syntax for case statements. Ended the starting case line with `of` instead of `->`. Ended the case clause with `end` instead of `}`.
Was overly apologetic about any mistake. It was kind of annoying

I had to write some code. The AI could not figure out the old versions of json parsing libraries and the new versions. It wrote code that didn't compile, every. single. time. I wrote the encoder and decoder functions for Coord data type and told it to use that as the pattern for the remaining data types. Amp code seems to work the best there.

Running game locally
- Install Battlesnakes CLI go install github.com/BattlesnakeOfficial/rules/cli/battlesnake@latest
- ╰─ battlesnake play -W 11 -H 11 --name 'dave1' --url http://localhost:8080 --name 'dave2' --url http://localhost:8080 --viewmap                                                     ─╯
