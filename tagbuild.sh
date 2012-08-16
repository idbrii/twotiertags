#! /bin/bash

# Instance config {{{
filetype=c

root="$HOME/data/code/public-clones/gish"
working_root='game'

if 0; then # simple setup
    working_set='. ../audio'
    other_set='input math menu parser physics sdl video'

else # complex setup
    # use grep to find the files that we want to build tags for
    # this way I don't need to explicitly list everything.
    #
    taginclude=' input math menu parser physics sdl video'
    # convert to grep format (previous must start with a space!)
    taginclude=${taginclude// / -e /}
    # all of our packages are 2 levels deep. sadly I can't put wholename here
    # because of quoting I think.
    find_args="-maxdepth 2 -mindepth 2 -type d"

    # This is what I think I'll use the most. (engine/src/libraryname/common is
    # for nonplatform-specific code. Ignore the platform-specific stuff.)
    cd $root/$working_root
    #working_set='. ../audio'
    working_set=`find . ../engine/src $find_args -wholename '*common*' | grep $taginclude`
    # add content
    working_set="$working_set ../content/ ../engine/content/"
    cd -
    # This should be everything else (except platform-specific stuff)
    cd $root
    other_set=`find src engine/src $find_args -wholename '*common*' | grep -v $taginclude`
    cd -
fi
# }}}


# General config {{{
temp_name='temp.tags'
cscope=cscope
if command -v $cscope > /dev/null ; then
    echo
else
	cscope=mlcscope
fi
tags_exclude_file=~/.tags_exclude.txt

# }}}


# Database build driver functions {{{

function __run_ctags {
    filetype=$1

    # Instead of matching the script object name, use the code name so we can
    # jump from code to the def file.
    SCRIPT_REGEX='/^[\t ]*(struct|enum) +([^ :]+):?.*$/t\2/'

    case $filetype in
        local)
            LANGUAGES="C,C++,C#,lua,script"
            LANGMAPS="C#:+.ddf,C#:+.adf,C++:+.inl,script:.script"

            ctags --c++-kinds=+p --fields=+iaS --extra=+q \
                --langscript=script --languages=$LANGUAGES --langmap=$LANGMAPS \
                --regex-script="$SCRIPT_REGEX" -L ctags.files
            ;;
        script)
            LANGUAGES="script"
            LANGMAPS="script:.script"

            ctags --langdef=script \
                --languages=$LANGUAGES --langmap=$LANGMAPS \
                --regex-script="$SCRIPT_REGEX" -L ctags.files
            ;;
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
    cscope_files=$3
    if [ "$cscope_files" == "" ] ; then
        cscope_files=cscope.files
    fi

    case $filetype in
        python)
            # Requires the python package pycscope:
            #   pip install pycscope
            pycscope.py -i $cscope_files
            ;;
        *)
            # Build cscope database
            #	-b              Build the database only.
            #	-k              Kernel Mode - don't use /usr/include for #include files.
            #	-q              Build an inverted index for quick symbol seaching.
            # May want to consider these flags
            #	-m "lang"       Use lang for multi-lingual cscope.
            #	-R              Recurse directories for files.
            $cscope -b -q -k -i $cscope_files
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
        local)
			# just fallthrough to cpp
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

    find $folders -type f "${find_ftype[@]}" -print | sed -e"s/.cygdrive.c/c:/g" | sort -f >> $temp_name
}

function __build_ctags_index {
    cut -f2 $temp_name > ctags.files
    __run_ctags $filetype

	# filter out nonsense (from macros)
	mv tags unfiltered.tags
	grep -vf $tags_exclude_file unfiltered.tags > tags

	rm unfiltered.tags ctags.files
}

function __build_lookupfile_index {
	# add config file to beginning of file list
	cat > filelist << END
build/pc/user.ini
END
    # add files
    sort -f $temp_name >> filelist
}

function __build_cscope_index {
    # linux requires relative names?
    #cut -f2 $temp_name | sed -e"s|^|$root/|" > cscope.files
    # and windows doesn't?
    __run_cscope $filetype $cscope $temp_name
}

# }}}

# Setup {{{
touch $root/$temp_name $root/$working_root/$temp_name
rm $root/$temp_name $root/$working_root/$temp_name
# }}}

# Build root indexes {{{
cd $root

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

cd -
# }}}

# Build working set indexes {{{
cd $root/$working_root

__append_intermediate_index $working_set

# ctags only uses the subset
__build_ctags_index $filetype

cd -
# }}}

# Cleanup {{{
rm $root/$temp_name $root/$working_root/$temp_name
# }}}

# vi:et:sw=4 ts=4 fdm=marker

