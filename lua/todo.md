easymotion highlighting

https://github.com/easymotion/vim-easymotion/blob/master/autoload/EasyMotion/highlight.vim#L173

also theres some useful shit here about :messages
and also about getting errors like wtf happened to grappler for example!!!
https://neovim.io/doc/user/message.html

!!!!!!!!!!!!!!!!!!!!!!!!!
when a name argument in whichkey is missing we get E471 Missing Argument

also for some reason when the second argument is
name="my keymap name"
that also fails silently.......... without the E471...

even tho arg1, arg2, remap=true works so clearly named arguments are a thing, and name={} for a whole section seems to work???

so just do arg1, arg2 for whichkey hehe

---

little used
["_"] = { "<C-w>w", "Previous window / focus foreground window" },
["|"] = { "<C-w>w", "Previous window / focus foreground window" },
