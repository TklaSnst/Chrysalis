# Powerlevel10k в цветах темы Chrysalis.
#
# p10k configure пишет в ~/.p10k.zsh цвета из 256-цветной палитры
# (31, 76, 178…), а theme-apply перекрашивает только 16 цветов терминала.
# Этот файл подключается после ~/.p10k.zsh и переводит каждый такой цвет
# в ближайший из 16 (красный → 1, синий → 4, яркий синий → 12, серый → 8…),
# поэтому приглашение меняет цвета вместе с темой, сам ~/.p10k.zsh не трогается.
# Подключение (install.sh добавляет само):
#   [[ ! -f ~/.config/zsh/p10k-chrysalis.zsh ]] || source ~/.config/zsh/p10k-chrysalis.zsh

# 256-цветный номер → номер из 16; цвета 0..15 и hex не трогаются
_chrysalis_ansi() {
    local n=$1
    (( n < 16 || n > 255 )) && { print -r -- $n; return }
    if (( n >= 232 )); then                       # серая шкала
        (( n < 244 )) && print 8 || print 7
        return
    fi
    local r=$(( (n - 16) / 36 )) g=$(( (n - 16) % 36 / 6 )) b=$(( (n - 16) % 6 ))
    local hi=$(( r > g ? (r > b ? r : b) : (g > b ? g : b) ))
    local lo=$(( r < g ? (r < b ? r : b) : (g < b ? g : b) ))
    if (( hi - lo <= 1 )); then                   # почти без цвета
        (( hi < 3 )) && print 8 || print 7
        return
    fi
    # «включённые» каналы — близкие к максимуму (у тёмных тонов — равные ему)
    local t=$(( hi <= 3 ? hi : hi - 1 ))
    local on=$(( (r >= t ? 4 : 0) | (g >= t ? 2 : 0) | (b >= t ? 1 : 0) ))
    # оранжевый — в жёлтый (оранжевого в 16 цветах нет), фиолетовый — в пурпурный
    (( r == hi && b == lo && g >= 2 && g < hi )) && on=6
    (( b == hi && r >= hi - 2 && r > g )) && on=5
    local base
    case $on in
        4) base=1 ;;                              # красный
        6) base=3 ;;                              # жёлтый / оранжевый
        2) base=2 ;;                              # зелёный
        3) base=6 ;;                              # бирюзовый
        1) base=4 ;;                              # синий
        5) base=5 ;;                              # пурпурный
        *) base=7 ;;
    esac
    (( hi == 5 && base != 7 )) && base=$(( base + 8 ))  # яркие — в bright-вариант
    print -r -- $base
}

() {
    local p v
    for p in ${(M)${(k)parameters}:#POWERLEVEL9K_*(FOREGROUND|BACKGROUND|COLOR)}; do
        v=${(P)p}
        [[ $v == <-> ]] || continue
        typeset -g $p=$(_chrysalis_ansi $v)
    done
}
unfunction _chrysalis_ansi

(( ! $+functions[p10k] )) || p10k reload
