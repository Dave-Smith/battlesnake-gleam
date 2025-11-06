Gemini 2.0 Flash was very good at writing incorrect syntax for case statements. Ended the starting case line with `of` instead of `->`. Ended the case clause with `end` instead of `}`.
Was overly apologetic about any mistake. It was kind of annoying

I had to write some code. The AI could not figure out the old versions of json parsing libraries and the new versions. It wrote code that didn't compile, every. single. time. I wrote the encoder and decoder functions for Coord data type and told it to use that as the pattern for the remaining data types. Amp code seems to work the best there.

Running game locally
- Install Battlesnakes CLI go install github.com/BattlesnakeOfficial/rules/cli/battlesnake@latest
- ╰─ battlesnake play -W 11 -H 11 --name 'dave1' --url http://localhost:8080 --name 'dave2' --url http://localhost:8080 --viewmap                                                     ─╯

Added a test snake named [Esproso](https://github.com/Tch1b0/Esproso) that I found on GitHub to my local testing. This snake is super aggressive in food finding. My snakes posture is to stay small and find food when competitors start growing or when my health is below a threshold. This new competitor caused food scarcity quickly causing my snake to prioritize food over safety. I need to tweak the heuristic weights to match the agressive food finding to not be started and making poor choices.
