
# Popc

Popc in *layer manager*, including layers of buffer, bookmark, worksapce.....

<div align="center">
<img alt="Popc" src="https://github.com/yehuohan/popc/blob/master/README/popc.gif"  width=75% height=75% />
</div>

 - buffer layer

<div align="center">
<img alt="Buffer" src="https://github.com/yehuohan/popc/blob/master/README/buf.png"  width=75% height=75% />
</div>

 - bookmark layer

<div align="center">
<img alt="Bookmark" src="https://github.com/yehuohan/popc/blob/master/README/bms.png"  width=75% height=75% />
</div>

 - workspace layer

<div align="center">
<img alt="Workspace" src="https://github.com/yehuohan/popc/blob/master/README/wks.png"  width=75% height=75% />
</div>

## Search

Use [LeaderF](https://github.com/Yggdroot/LeaderF) to search file or context in buffer, workspace or bookmark files.

More usage help in [popc.txt](https://github.com/yehuohan/popc/blob/master/doc/popc.txt).


## Add Customized layer

All you need to do is implement one *layer* struct and add to *s:popc*. The [Example layer](https://github.com/yehuohan/popc/blob/master/autoload/popc/layer/exp.vim) can be a good example layer to start.

Plugins using popc:
 - [popset](https://github.com/yehuohan/popset)


## Thinks

**Popc** is inspired by [vim-CtrlSpapce](https://github.com/vim-ctrlspace/vim-ctrlspace) and its one fork [vim-CtrlSpapce](https://github.com/yehuohan/vim-ctrlspace).
