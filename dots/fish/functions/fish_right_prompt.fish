# справа: только сколько шла долгая команда (время и дата теперь слева)
# on the right: only how long a long command took (time and date are on the left now)
function fish_right_prompt
    if test $CMD_DURATION -gt 3000
        set_color brblack
        echo -n (math -s1 $CMD_DURATION / 1000)'с'
        set_color normal
    end
end
