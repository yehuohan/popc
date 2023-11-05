
# Popc

Popc in *layer manager*, including layers of buffer, bookmark, worksapce.....

 - buffer layer

<div align="center">
<img alt="Buffer" src="README/buf.gif"  width=75% height=75% />
</div>

Buffer layer can keep buffers scooped under tabpages.

 - bookmark layer

<div align="center">
<img alt="Bookmark" src="README/bms.gif"  width=75% height=75% />
</div>

Bookmark layer can manage you own bookmark files. 

 - workspace layer

<div align="center">
<img alt="Workspace" src="README/wks.gif"  width=75% height=75% />
</div>

Workspace layer can save sessions, including buffer layer layout.

> Support floating window of neovim(0.4.3+) and popupwin of vim (version 802+) with `let g:Popc_useFloatingWin = 1`.


## Search

Use [LeaderF](https://github.com/Yggdroot/LeaderF) to search file or context in buffer, workspace or bookmark files.

More usage help in [popc.txt](doc/popc.txt).


## Add Customized layer

All you need to do is implement one *layer* struct and add to *s:popc*. The [Example layer](autoload/popc/layer/exp.vim) can be a good example layer to start.

Plugins using popc:
 - [popset](https://github.com/yehuohan/popset)
 - [popc-floaterm](https://github.com/yehuohan/popc-floaterm)


## Thinks

**Popc** is inspired by [vim-CtrlSpapce](https://github.com/vim-ctrlspace/vim-ctrlspace) and its one fork [vim-CtrlSpapce](https://github.com/yehuohan/vim-ctrlspace).
