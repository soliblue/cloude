#!/bin/bash
cd /Users/soli/Desktop/CODING/cloude/.claude/skills/speak

python3 generate.py "Ten pixel creatures." -v bf_emma -s 0.9 -o narr-02-roster
python3 generate.py "Mood boards. Story frames." -v bf_emma -s 0.9 -o narr-03-moodboards
python3 generate.py "Space Invaders flickers." -v bf_emma -s 0.9 -o narr-04-invaders
python3 generate.py "Rainbow Road races." -v bf_emma -s 0.9 -o narr-05-kart
python3 generate.py "Samurai fights." -v bf_emma -s 0.9 -o narr-06-fighter
python3 generate.py "Dungeons glow." -v bf_emma -s 0.9 -o narr-07-zelda
python3 generate.py "Tetris falls." -v bf_emma -s 0.9 -o narr-08-tetris
python3 generate.py "And it dances." -v bf_emma -s 0.9 -o narr-09-ddr
python3 generate.py "Twenty videos. Zero credits left." -v bf_emma -s 0.9 -o narr-10-end
