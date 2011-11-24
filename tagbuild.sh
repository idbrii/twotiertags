#! /bin/bash

# Instance config {{{
filetype=c

root="$HOME/data/code/public-clones/gish"
other_set='input math menu parser physics sdl video'

working_root='game'
working_set='. ../audio'

# }}}


# General config {{{
temp_name='temp.tags'
cscope=cscope

# }}}


# Database build driver functions {{{

function __run_ctags {
    filetype=$1

    case $filetype in
        cpp|cs|c)
            ctags --c++-kinds=+p --fields=+iaS --extra=+q -L ctags.files
            ;;
        *)
            ctags -L ctags.files
            ;;
    esac
}

function __run_cscope {
    filetype=$1
    cscope=$2

    case $filetype in
        python)
            # Requires the python package pycscope:
            #   pip install pycscope
            pycscope.py -i cscope.files
            ;;
        *)
            # Build cscope database
            #	-b              Build the database only.
            #	-k              Kernel Mode - don't use /usr/include for #include files.
            #	-q              Build an inverted index for quick symbol seaching.
            # May want to consider these flags
            #	-m "lang"       Use lang for multi-lingual cscope.
            #	-R              Recurse directories for files.
            $cscope -b -q -k
            ;;
    esac
}

# }}}

# Index builder functions {{{

function __append_intermediate_index {
    # expects temp_name to a temporary filename for output
    folders=$*

    declare -a find_ftype
    case $filetype in
        cpp)
            find_ftype[0]="("
            find_ftype[1]="-iname"
            find_ftype[2]="*.cpp"
            find_ftype[3]="-o"
            find_ftype[4]="-iname"
            find_ftype[5]="*.h"
            find_ftype[6]="-o"
            find_ftype[7]="-iname"
            find_ftype[8]="*.inl"
            find_ftype[9]=")"
            ;;
        c)
            find_ftype[0]="("
            find_ftype[1]="-iname"
            find_ftype[2]="*.c"
            find_ftype[3]="-o"
            find_ftype[4]="-iname"
            find_ftype[5]="*.h"
            find_ftype[6]=")"
            ;;
        cs)
            find_ftype[0]="("
            find_ftype[1]="-iname"
            find_ftype[2]="*.cs"
            find_ftype[3]=")"
            ;;
        *)
            # use no name filter
            find_ftype[0]=""
            ;;
    esac

    find $folders -type f "${find_ftype[@]}" -printf "%f\t%p\t1\n" | sed -e"s/.cygdrive.c/c:/g" | sort -f >> $temp_name
}

function __build_ctags_index {
    cut -f2 $temp_name > ctags.files
    __run_ctags $filetype
    rm ctags.files
}

function __build_lookupfile_index {
    echo "!_TAG_FILE_SORTED	2	/2=foldcase/"> filenametags
    sort -f $temp_name >> filenametags
}

function __build_cscope_index {
    cut -f2 $temp_name | sed -e"s|^|$root/|" > cscope.files
    __run_cscope $filetype $cscope
    rm cscope.files
}

# }}}

# Build root indexes {{{
cd $root

rm $temp_name
__append_intermediate_index $other_set

# ctags only uses the subset
__build_ctags_index

working_set_from_root=
for d in $working_set; do
    working_set_from_root="$working_set_from_root $working_root/$d"
done
__append_intermediate_index $working_set_from_root

# lookupfile and cscope use all
__build_lookupfile_index

# cscope needs absolute paths, so append our current dir
__build_cscope_index

rm $temp_name

cd -
# }}}

# Build working set indexes {{{
cd $root/$working_root

rm $temp_name
__append_intermediate_index $working_set

# ctags only uses the subset
__build_ctags_index $filetype

rm $temp_name

cd -
# }}}


# vi:et:sw=4 ts=4 fdm=marker
