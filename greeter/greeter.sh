#!/bin/sh
# экран входа: mango + наш greeter. Весь вывод — мимо экрана, иначе при входе мелькали логи mango
# login screen: mango + our greeter. All output goes past the screen, otherwise mango's logs flashed on login
exec mango -c /etc/greetd/nyagreet/mango-greeter.conf -s 'qs -p /etc/greetd/nyagreet/shell.qml; mmsg dispatch quit' >/dev/null 2>&1
