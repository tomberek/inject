#!/usr/bin/env bash
encode ()
{
    #parallel -qk -N1 --pipe base32 | tr -d '=' | tr 'A-Z2-7' ' !"#$%&'"'"'()*+,-./0-9:;<=>?'
    parallel -qk -N1 --pipe base32 | tr -d '=' | tr 'A-Z2-7' ' -?'
}
decode ()
{
    tr ' -?' 'A-Z2-7' | awk '{padding="";l=length($0)%8;for(i=0;l!=0 && i<8-l; i++){padding=padding "="}; printf "%s%s\n",$0,padding}' | parallel -qk -N1 --pipe base32 -d
    #tr ' !"#$%&'"'"'()*+,-./0-9:;<=>?' 'A-Z2-7' | awk '{padding="";l=length($0)%8;for(i=0;l!=0 && i<8-l; i++){padding=padding "="}; printf "%s%s\n",$0,padding}' | parallel -qk -N1 --pipe base32 -d

}
embed ()
{
    awk -v FILE=$1 'BEGIN{srand()}
        {
            getline line < FILE
            r=int(rand()*length(line))
            printf "%s[%sz%s\n",substr(line,1,r),$0,substr(line,r+1,length(line)-r)
        }
        END {
        while((getline line < FILE) >0)
            printf "%s\n",line
        }'
}
extract ()
{
    sed 's/.*\\[\([^z]*\).*/\1/g'
}
export -f encode
export -f decode
export -f embed
export -f extract
#echo -e "hi\nworld" | encode | embed <(echo -e "test line 1\ntest line 2") | extract | decode
