## What does this do?

This reads the sensor value on an HP ProLiant DL360pGen8 server, and set sthe fan speeds accordingly

## Why?

I run non HP drives, and they spin to 100% and don't ramp up/down with temperature

## Who?

This is for owners of very sepcific server, DL360pgen8. I run VMWare esxi, with a mix of windows and ubuntu VM's, with an environment that changes temp a lot. You will nee dto be comfortable with linux, but honestly you can probably fumble it through with ChatGPT/Claude Free.

## How?

I followed this guide:

https://www.reddit.com/r/homelab/comments/sx3ldo/hp_ilo4_v277_unlocked_access_to_fan_controls/

Then I created this script (with much SSH wrangling) then installed it on an Ubuntu VM and put it on a 10min cron job

## Disclaimer

This is a hyper focused script, it is probably not that useful for other people, but when you google the subject you tend to find scary comments about reflashing, so I wrote my own. I hope it can help you, but you take on all the responsobility for what you attempt.
