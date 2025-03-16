#!/bin/bash

# Скрипт для создания загрузочной флешки Windows 11 на macOS
# Стильный интерфейс в современном дизайне
# Для компьютера Dell OptiPlex 3070 Micro
# Версия с улучшенным дизайном и исправленными ошибками

# ==================== НАСТРОЙКИ ЦВЕТОВ И СТИЛЯ ====================
# Расширенная палитра цветов
RESET="\033[0m"
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BRIGHT_BLACK="\033[90m"
BRIGHT_RED="\033[91m"
BRIGHT_GREEN="\033[92m"
BRIGHT_YELLOW="\033[93m"
BRIGHT_BLUE="\033[94m"
BRIGHT_MAGENTA="\033[95m"
BRIGHT_CYAN="\033[96m"
BRIGHT_WHITE="\033[97m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
BLINK="\033[5m"
REVERSE="\033[7m"
HIDDEN="\033[8m"

# Специальные цветовые комбинации для темы
PRIMARY="\033[38;5;33m"       # Яркий синий
SECONDARY="\033[38;5;39m"     # Средний синий
ACCENT="\033[38;5;45m"        # Голубой
WARNING="\033[38;5;214m"      # Оранжевый
ERROR="\033[38;5;196m"        # Яркий красный
SUCCESS="\033[38;5;46m"       # Яркий зеленый
INFO="\033[38;5;87m"          # Средний голубой
BORDER="\033[38;5;24m"        # Темно-синий
TITLE_BG="\033[48;5;25m"      # Фон для заголовков
BOX_TITLE="\033[38;5;231m\033[48;5;25m\033[1m" # Белый текст на синем фоне с жирным
WINDOWS_BLUE="\033[38;5;27m"  # Синий Windows
WINDOWS_GREEN="\033[38;5;34m" # Зеленый Windows
WINDOWS_RED="\033[38;5;196m"  # Красный Windows
WINDOWS_YELLOW="\033[38;5;226m" # Желтый Windows

# ==================== ПЕРЕМЕННЫЕ ====================
VERSION="4.1"  # Обновлена версия после исправлений
ISO_PATH=""
USB_DISK=""
MOUNT_DIR=""
USB_MOUNT=""
LOG_FILE="win11_flash_$(date +%Y%m%d_%H%M%S).log"
TERM_WIDTH=$(tput cols || echo 80)  # Проверка на случай, если tput не работает
TERM_HEIGHT=$(tput lines || echo 24)  # Проверка на случай, если tput не работает
PADDING=2  # Оступ от края терминала
SPINNER_PID=""  # PID процесса спиннера
SIMPLE_UI=false  # Флаг для упрощенного интерфейса
CACHE_DIR="${TMPDIR:-/tmp}/win11_creator_cache"  # Директория для кэширования

# Создаем директорию для кэша
mkdir -p "$CACHE_DIR" 2>/dev/null

  # После определения кэш-директории и перед любыми операциями
  # Проверяем системные зависимости
  check_system_dependencies

# Объединенная функция проверки системных требований и зависимостей
check_system_dependencies() {
  log "INFO" "Проверка системных зависимостей"
  
  # Проверяем наличие необходимых утилит
  local missing_tools=()
  local required_tools=("diskutil" "hdiutil" "rsync" "wc" "awk" "sed" "grep" "find" "mktemp")
  
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
      log "ERROR" "Утилита не найдена: $tool"
    fi
  done
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${ERROR}${BOLD}Отсутствуют необходимые утилиты: ${missing_tools[*]}${RESET}"
    echo -e "${INFO}Эти утилиты необходимы для работы скрипта.${RESET}"
    exit 1
  fi
  
  # Проверяем кэш-директорию
  if ! check_cache_dir; then
    echo -e "${ERROR}${BOLD}Невозможно использовать кэш-директорию.${RESET}"
    echo -e "${INFO}Проверьте права доступа и наличие свободного места.${RESET}"
    exit 1
  fi
  
  # Проверяем терминал
  if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    log "WARNING" "Обнаружен минимальный терминал ($TERM), переключение на упрощенный интерфейс"
    SIMPLE_UI=true
  fi
  
  # Проверяем размер терминала
  if [ "$TERM_WIDTH" -lt 40 ] || [ "$TERM_HEIGHT" -lt 10 ]; then
    log "WARNING" "Обнаружен очень маленький терминал (${TERM_WIDTH}x${TERM_HEIGHT}), переключение на упрощенный интерфейс"
    SIMPLE_UI=true
  fi
  
  # Выполняем дополнительные проверки из check_requirements
  clear_screen
  draw_fullscreen_box "Проверка системных требований"
  
  local required_tools=("diskutil" "hdiutil" "rsync" "file" "mktemp")
  local missing_tools=()
  
  echo
  local width=$(draw_info_block "Проверка утилит")
  
  # Запускаем спиннер загрузки
  loading_spinner "Проверка системных компонентов..." 5
  
  # Имитация задержки проверки для демонстрации анимации
  sleep 1.5
  
  # Останавливаем спиннер
  stop_spinner
  
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      missing_tools+=("$tool")
      draw_block_line "[ ] ${ERROR}$tool${RESET} - не найден"
    else
      draw_block_line "[${SUCCESS}✓${RESET}] $tool - найден"
    fi
    sleep 0.2  # Красивая анимация последовательного появления строк
  done
  
  close_info_block
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo
    show_error_message "Не найдены утилиты: ${missing_tools[*]}"
    echo
    echo -e "${INFO}[Нажмите Enter для выхода]${RESET}"
    read
    exit 1
  else
    echo
    show_success_message "Все необходимые утилиты найдены"
  fi
  
  # Проверка запуска от имени администратора
  echo
  if [ "$(id -u)" -ne 0 ]; then
    show_warning_message "Скрипт запущен без прав администратора"
    draw_content_line "   ${WARNING}Для корректной работы рекомендуется запускать с sudo${RESET}"
    
    local continue_without_sudo=$(ask_yes_no "Продолжить без прав администратора?" "n")
    
    if [ "$continue_without_sudo" = "false" ]; then
      echo -e "${INFO}Перезапустите скрипт с sudo: ${ACCENT}sudo $0 $SCRIPT_ARGS${RESET}"
      exit 0
    fi
  else
    show_success_message "Скрипт запущен с правами администратора"
  fi
  
  # Системная информация
  local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "Неизвестно")
  local system_free_space=$(df -h / | tail -1 | awk '{print $4}')
  
  echo
  local width=$(draw_info_block "Системная информация")
  
  # Анимируем появление информации
  sleep 0.3
  draw_block_line "Версия macOS: ${ACCENT}$macos_version${RESET}"
  sleep 0.3
  draw_block_line "Свободное место на системном диске: ${ACCENT}$system_free_space${RESET}"
  
  close_info_block
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
  
  log "INFO" "Проверка системных зависимостей завершена успешно"
  return 0
}

# ==================== СЛУЖЕБНЫЕ ФУНКЦИИ ====================

# Очистка экрана
clear_screen() {
  clear || printf "\033c"  # Альтернативный способ очистки, если clear не работает
}

# Улучшенное логирование с более надежной ротацией файлов
log() {
  local level=$1
  local message=$2
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local log_dir=$(dirname "$LOG_FILE")
  
  # Создаем директорию для логов при необходимости
  if [ "$log_dir" != "." ] && [ ! -d "$log_dir" ]; then
    mkdir -p "$log_dir" 2>/dev/null
    if [ $? -ne 0 ]; then
      # Если не удалось создать директорию, используем временную
      LOG_FILE="${TMPDIR:-/tmp}/win11_creator_log_$.log"
      echo "Не удалось создать директорию для логов. Используем: $LOG_FILE" >&2
    fi
  fi
  
  echo -e "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
  
  # Ротация логов при превышении размера (10 МБ)
  # Используем wc -c вместо stat -f %z для лучшей портируемости
  if [ -f "$LOG_FILE" ]; then
    local log_size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$log_size" -gt 10485760 ]; then
      mv "$LOG_FILE" "${LOG_FILE}.old" 2>/dev/null
    fi
  fi
}

# Проверка ошибок с возможностью восстановления
check_error() {
  local exit_code=$?
  local error_message="$1"
  local recovery_function="$2"
  
  if [ $exit_code -ne 0 ]; then
    echo -e "${ERROR}${BOLD}[✗] ОШИБКА: $error_message${RESET}"
    log "ERROR" "$error_message"
    
    if [ -n "$recovery_function" ]; then
      echo -e "${INFO}${BOLD}Попытаться исправить? (Y/n): ${RESET}"
      read -r fix_answer
      fix_answer=$(echo "$fix_answer" | tr '[:upper:]' '[:lower:]')
      
      if [ -z "$fix_answer" ] || [ "$fix_answer" = "y" ]; then
        $recovery_function
        return $?
      fi
    fi
    
    echo
    echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
    read
    return $exit_code
  fi
  
  return 0
}

# Функция для проверки и создания кэш-директории
check_cache_dir() {
  # Проверяем наличие кэш-директории
  if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR" 2>/dev/null
    if [ $? -ne 0 ]; then
      log "WARNING" "Не удалось создать кэш-директорию: $CACHE_DIR"
      # Пробуем использовать системную временную директорию
      CACHE_DIR="${TMPDIR:-/tmp}/win11_creator_cache_$"
      log "INFO" "Используем альтернативную кэш-директорию: $CACHE_DIR"
      mkdir -p "$CACHE_DIR" 2>/dev/null
      if [ $? -ne 0 ]; then
        log "ERROR" "Не удалось создать альтернативную кэш-директорию: $CACHE_DIR"
        show_error_message "Невозможно создать кэш-директорию. Проверьте права доступа."
        return 1
      fi
    fi
  fi
  
  # Проверяем права на запись в кэш-директорию
  if [ ! -w "$CACHE_DIR" ]; then
    log "ERROR" "Нет прав на запись в кэш-директорию: $CACHE_DIR"
    show_error_message "Нет прав на запись в кэш-директорию: $CACHE_DIR"
    return 1
  fi
  
  # Проверяем, есть ли достаточно места (хотя бы 1MB)
  local cache_free=$(df -k "$CACHE_DIR" | tail -1 | awk '{print $4}')
  if [ "$cache_free" -lt 1024 ]; then
    log "WARNING" "Мало места в кэш-директории: $CACHE_DIR (${cache_free}KB)"
    show_warning_message "Мало места в кэш-директории. Это может привести к ошибкам."
  fi
  
  return 0
}

# Рисуем полный экран рамок
draw_fullscreen_box() {
  local title="$1"
  local width=$((TERM_WIDTH - PADDING*2))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${BORDER}==== ${BOX_TITLE}$title${BORDER} ====${RESET}"
    return
  fi
  
  # Верхняя рамка с заголовком
  echo -e "${BORDER}┏━━${BOX_TITLE} ${title} ${BORDER}━━${RESET}"
  
  # Создаем нижнюю линию с правильной длиной, учитывая заголовок
  local title_len=${#title}
  local remaining_width=$((width - title_len - 6))
  local right_border=$(printf '%*s' $remaining_width | tr ' ' '━')
  
  echo -e "${BORDER}${right_border}┓${RESET}"
  
  # Пустая строка в начале
  echo -e "${BORDER}┃${RESET}$(printf '%*s' $width)${BORDER}┃${RESET}"
}

# Закрываем полный экран рамок
close_fullscreen_box() {
  local width=$((TERM_WIDTH - PADDING*2))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${BORDER}=================================${RESET}"
    return
  fi
  
  # Пустая строка в конце
  echo -e "${BORDER}┃${RESET}$(printf '%*s' $width)${BORDER}┃${RESET}"
  
  # Нижняя рамка
  echo -e "${BORDER}┗$(printf '%*s' $width | tr ' ' '━')┛${RESET}"
}

# Рисуем заголовок в стильном дизайне
draw_fancy_header() {
  local title="$1"
  local width=$((TERM_WIDTH - PADDING*2))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${BORDER}==== ${BOX_TITLE}$title${BORDER} ====${RESET}"
    return
  fi
  
  echo -e "${BORDER}┏━━${BOX_TITLE} ${title} ${BORDER}━━${RESET}"
  
  # Создаем нижнюю линию с правильной длиной, учитывая заголовок
  local title_len=${#title}
  local remaining_width=$((width - title_len - 6))
  local right_border=$(printf '%*s' $remaining_width | tr ' ' '━')
  
  echo -e "${BORDER}${right_border}┓${RESET}"
}

# Рисуем подвал в стильном дизайне
draw_fancy_footer() {
  local width=$((TERM_WIDTH - PADDING*2))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${BORDER}=================================${RESET}"
    return
  fi
  
  echo -e "${BORDER}┗$(printf '%*s' $width | tr ' ' '━')┛${RESET}"
}

# Рисуем разделительную линию
draw_separator() {
  local width=$((TERM_WIDTH - PADDING*2))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${BORDER}--------------------------------${RESET}"
    return
  fi
  
  echo -e "${BORDER}┣$(printf '%*s' $width | tr ' ' '━')┫${RESET}"
}

# Рисуем строку с контентом
draw_content_line() {
  local content="$1"
  local width=$((TERM_WIDTH - PADDING*2))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${content}"
    return
  fi
  
  # Вычисляем видимую длину (без анси-кодов)
  local visible_content=$(echo -e "$content" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
  local content_length="${#visible_content}"
  local spaces=$((width - content_length))
  
  # Проверка, чтобы spaces не был отрицательным
  if [ $spaces -lt 0 ]; then
    spaces=0
  fi
  
  echo -e "${BORDER}┃${RESET} ${content}$(printf '%*s' $spaces '')${BORDER}┃${RESET}"
}

# Рисуем красивый блок с информацией
draw_info_block() {
  local title="$1"
  local width=$((TERM_WIDTH - PADDING*2 - 4))  # -4 для внутренних отступов блока
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${PRIMARY}--- ${title} ---${RESET}"
    return $width
  fi
  
  echo -e "${BORDER}┃${RESET}  ${PRIMARY}┌──${BOX_TITLE} ${title} ${PRIMARY}$(printf '%*s' $((width - ${#title} - 5)) '' | tr ' ' '─')┐${RESET}  ${BORDER}┃${RESET}"
  
  # Возвращаем ширину для использования в содержимом
  echo $width
}

# Закрыть красивый блок с информацией
close_info_block() {
  local width=$((TERM_WIDTH - PADDING*2 - 4))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "${PRIMARY}----------------------------${RESET}"
    return
  fi
  
  echo -e "${BORDER}┃${RESET}  ${PRIMARY}└$(printf '%*s' $width '' | tr ' ' '─')┘${RESET}  ${BORDER}┃${RESET}"
}

# Вывод строки в блоке
draw_block_line() {
  local content="$1"
  local width=$((TERM_WIDTH - PADDING*2 - 4))
  
  # Обработка для узких терминалов
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "  ${content}"
    return
  fi
  
  # Вычисляем видимую длину (без анси-кодов)
  local visible_content=$(echo -e "$content" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
  local content_length="${#visible_content}"
  local spaces=$((width - content_length))
  
  # Проверка, чтобы spaces не был отрицательным
  if [ $spaces -lt 0 ]; then
    spaces=0
  fi
  
  echo -e "${BORDER}┃${RESET}  ${PRIMARY}│${RESET} ${content}$(printf '%*s' $spaces '')${PRIMARY}│${RESET}  ${BORDER}┃${RESET}"
}

# Для одиночных файлов - отображаем прогресс копирования с использованием универсальной функции
handle_single_file_progress() {
  local file="$1"
  local current=$2
  local total=$3
  local base_file=$(basename "$file")
  
  # Вызываем универсальную функцию с конкретными параметрами
  show_progress "Копирование файла: $base_file" "$total" "$current" "false"
}

# Индикатор прогресса для общего прогресса копирования
show_copy_progress() {
  local message="$1"
  local width=$((TERM_WIDTH - PADDING*2 - ${#message} - 10))
  local bar_length=40
  local wait_time=1  # Более длительное время ожидания для копирования
  
  # Упрощенный прогресс для маленьких терминалов
  if [ "$SIMPLE_UI" = true ] || [ $width -lt 50 ]; then
    bar_length=20
  fi
  
  # Получаем общее количество файлов в ISO
  local total_files=$(find "$MOUNT_DIR" -type f | wc -l | xargs)
  echo -e "${INFO}Всего файлов для копирования: ${ACCENT}$total_files${RESET}"
  
  # Создаем временный файл для отслеживания прогресса
  local progress_file="${CACHE_DIR}/copy_progress_$"
  echo "0" > "$progress_file"
  
  # Запускаем фоновый процесс для мониторинга количества скопированных файлов
  (
    while true; do
      # Подсчитываем количество скопированных файлов
      local copied_files=$(find "$USB_MOUNT" -type f 2>/dev/null | wc -l | xargs)
      echo "$copied_files" > "$progress_file"
      sleep 1
    done
  ) &
  local monitor_pid=$!
  
  # Останавливаем монитор при выходе
  trap "kill $monitor_pid 2>/dev/null; rm -f $progress_file 2>/dev/null" EXIT
  
  # Начальный прогресс-бар
  echo -e "\n${INFO}${BOLD}Общий прогресс копирования:${RESET}"
  
  local pos=0
  while [ $pos -lt 100 ]; do
    # Получаем текущий прогресс
    local copied_files=$(cat "$progress_file" 2>/dev/null || echo "0")
    
    # Вычисляем процент
    if [ $total_files -gt 0 ]; then
      pos=$((copied_files * 100 / total_files))
      # Защита от выхода за пределы
      [ $pos -gt 100 ] && pos=100
    fi
    
    # Отрисовка прогресс-бара
    printf "\r${message} [${PRIMARY}"
    for ((j=0; j<pos*bar_length/100; j++)); do
      printf "█"
    done
    
    for ((j=pos*bar_length/100; j<bar_length; j++)); do
      printf "${BRIGHT_BLACK}█${PRIMARY}"
    done
    
    printf "${RESET}] ${pos}%% ($copied_files/$total_files)"
    
    # Если копирование завершено, выходим из цикла
    if [ $pos -ge 100 ]; then
      break
    fi
    
    sleep $wait_time
  done
  
  # Завершающий прогресс-бар - всегда показываем 100%
  printf "\r${message} [${SUCCESS}"
  for ((j=0; j<bar_length; j++)); do
    printf "█"
  done
  printf "${RESET}] 100%%\n"
  
  # Завершаем мониторинг
  kill $monitor_pid 2>/dev/null
  rm -f "$progress_file" 2>/dev/null
  
  # Очищаем trap
  trap - EXIT
}

# Запрос ввода - стильный дизайн
ask_input() {
  local prompt="$1"
  local default="$2"
  local input=""
  
  if [ -n "$default" ]; then
    printf "${INFO}${BOLD}%s${RESET} [${ACCENT}%s${RESET}]: " "$prompt" "$default"
  else
    printf "${INFO}${BOLD}%s${RESET}: " "$prompt"
  fi
  
  read -r input
  
  # Логируем полученный ввод (без конфиденциальных данных)
  log "DEBUG" "Получен ввод: '$input'"
  
  if [ -z "$input" ] && [ -n "$default" ]; then
    echo "$default"
  else
    echo "$input"
  fi
}

# Запрос да/нет - стильный дизайн
ask_yes_no() {
  local prompt="$1"
  local default="$2"
  local input=""
  
  if [ "$default" = "y" ]; then
    prompt_with_default="${prompt} (${ACCENT}Y${RESET}/${WARNING}n${RESET})"
  else
    prompt_with_default="${prompt} (${ACCENT}y${RESET}/${WARNING}N${RESET})"
  fi
  
  printf "${INFO}${BOLD}%s${RESET}: " "$prompt_with_default"
  read -r input
  
  # Логируем полученный ответ
  log "DEBUG" "Получен ответ да/нет: '$input'"
  
  input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
  
  if [ -z "$input" ]; then
    input=$default
  fi
  
  if [ "$input" = "y" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# Исправленный loading_spinner с таймаутом
loading_spinner() {
  local message="$1"
  local delay=0.1
  local spinstr='|/-\'
  local timeout=${2:-60}  # Таймаут в секундах, по умолчанию 60
  local end_time=$(($(date +%s) + $timeout))
  
  printf "${INFO}%s " "$message"
  
  # Создаем временный файл для индикации завершения
  local spinner_done_file="${CACHE_DIR}/spinner_done_$$"
  touch "$spinner_done_file"
  
  # Запускаем спиннер в фоновом режиме
  {
    while [ -f "$spinner_done_file" ] && [ $(date +%s) -lt $end_time ]; do
      for i in {0..3}; do
        local c=${spinstr:$i:1}
        printf "\b${ACCENT}%s${RESET}" "$c"
        sleep $delay
      done
    done
    
    # Очищаем временный файл
    rm -f "$spinner_done_file" 2>/dev/null
  } &
  
  # Сохраняем PID процесса спиннера
  SPINNER_PID=$!
  disown
}

# Остановить спиннер
stop_spinner() {
  # Получаем результат операции (успех/ошибка)
  local result=${1:-"success"}  # По умолчанию успех
  
  # Останавливаем процесс со спиннером, если он запущен
  if [ -n "$SPINNER_PID" ] && ps -p "$SPINNER_PID" > /dev/null 2>&1; then
    # Удаляем файл, чтобы цикл спиннера завершился
    rm -f "${CACHE_DIR}/spinner_done_$" 2>/dev/null
    
    # Даем спиннеру время корректно завершиться
    sleep 0.2
    
    # Если процесс все еще запущен, принудительно завершаем
    if ps -p "$SPINNER_PID" > /dev/null 2>&1; then
      kill "$SPINNER_PID" 2>/dev/null
    fi
    
    # Очищаем PID
    SPINNER_PID=""
  fi
  
  # Выводим символ в зависимости от результата операции
  if [ "$result" = "success" ]; then
    printf "\b${SUCCESS}✓${RESET}\n"
  else
    printf "\b${ERROR}✗${RESET}\n"
  fi
}

# Отобразить стильную заставку в виде логотипа Windows
show_splash() {
  clear_screen
  
  local width=$((TERM_WIDTH - 20))
  local height=$((TERM_HEIGHT - 10))
  
  # Центрировать в терминале
  local top_padding=$((height / 4))
  local bottom_padding=$((height - top_padding))
  
  # Если терминал слишком маленький, используем упрощенную заставку
  if [ "$SIMPLE_UI" = true ]; then
    echo -e "\n${BRIGHT_WHITE}${BOLD}Windows 11 USB Creator v${VERSION}${RESET}\n"
    echo -e "${WHITE}Для Dell OptiPlex 3070 Micro${RESET}\n"
    echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
    read
    return
  fi
  
  # Отступы сверху
  for ((i=0; i<top_padding; i++)); do
    echo ""
  done
  
  # Создание отцентрированных строк для логотипа Windows
  local line1="  ${WINDOWS_BLUE}██████████████    ${WINDOWS_RED}██████████████  "
  local line2="  ${WINDOWS_BLUE}██████████████    ${WINDOWS_RED}██████████████  "
  local line3="  ${WINDOWS_BLUE}██████████████    ${WINDOWS_RED}██████████████  "
  local line4="  ${WINDOWS_BLUE}██████████████    ${WINDOWS_RED}██████████████  "
  local line5="                                "
  local line6="  ${WINDOWS_GREEN}██████████████    ${WINDOWS_YELLOW}██████████████  "
  local line7="  ${WINDOWS_GREEN}██████████████    ${WINDOWS_YELLOW}██████████████  "
  local line8="  ${WINDOWS_GREEN}██████████████    ${WINDOWS_YELLOW}██████████████  "
  local line9="  ${WINDOWS_GREEN}██████████████    ${WINDOWS_YELLOW}██████████████  "
  
  local title="${BRIGHT_WHITE}${BOLD}Windows 11 USB Creator${RESET}"
  local version="${ACCENT}Версия ${VERSION}${RESET}"
  local subtitle="${WHITE}Для Dell OptiPlex 3070 Micro${RESET}"
  local prompt="${INFO}[Нажмите Enter для продолжения]${RESET}"
  
  # Вывод каждой строки центрированно
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line1}) / 2 )) "")${line1}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line2}) / 2 )) "")${line2}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line3}) / 2 )) "")${line3}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line4}) / 2 )) "")${line4}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line5}) / 2 )) "")${line5}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line6}) / 2 )) "")${line6}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line7}) / 2 )) "")${line7}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line8}) / 2 )) "")${line8}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#line9}) / 2 )) "")${line9}"
  
  echo ""
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#title}) / 2 )) "")${title}"
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#version}) / 2 )) "")${version}"
  echo ""
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#subtitle}) / 2 )) "")${subtitle}"
  echo ""
  echo -e "$(printf "%*s" $(( (TERM_WIDTH - ${#prompt}) / 2 )) "")${prompt}"
  
  # Ожидаем нажатия клавиши
  read
}

# Отобразить сообщение об успешной операции
show_success_message() {
  local message="$1"
  echo -e "${SUCCESS}${BOLD}[✓] ${message}${RESET}"
  log "SUCCESS" "$message"
}

# Отобразить предупреждение
show_warning_message() {
  local message="$1"
  echo -e "${WARNING}${BOLD}[!] ${message}${RESET}"
  log "WARNING" "$message"
}

# Отобразить ошибку
show_error_message() {
  local message="$1"
  echo -e "${ERROR}${BOLD}[✗] ${message}${RESET}"
  log "ERROR" "$message"
}

# Отобразить информационное сообщение
show_info_message() {
  local message="$1"
  echo -e "${INFO}${BOLD}[i] ${message}${RESET}"
  log "INFO" "$message"
}

# Показать список доступных дисков в стильном дизайне
show_disk_list() {
  local width=$(draw_info_block "Список доступных дисков")
  
  # Кэшируем результат выполнения команды
  local disk_list=""
  if [ -f "${CACHE_DIR}/disk_list" ] && [ $(($(date +%s) - $(stat -f %m "${CACHE_DIR}/disk_list" 2>/dev/null || echo 0))) -lt 30 ]; then
    disk_list=$(cat "${CACHE_DIR}/disk_list")
  else
    disk_list=$(diskutil list)
    echo "$disk_list" > "${CACHE_DIR}/disk_list"
  fi
  
  echo "$disk_list" | while IFS= read -r line; do
    draw_block_line "$line"
  done
  
  close_info_block
}

# Универсальный обработчик ошибок
handle_error() {
  local error_code=$1
  local error_message=$2
  local recovery_function=$3
  
  show_error_message "$error_message"
  log "ERROR" "$error_message"
  
  if [ -n "$recovery_function" ]; then
    printf "${INFO}${BOLD}Попытаться устранить проблему? (Y/n): ${RESET}"
    read -r fix_answer
    fix_answer=$(echo "$fix_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$fix_answer" ] || [ "$fix_answer" = "y" ]; then
      $recovery_function
      return $?
    fi
  fi
  
  return $error_code
}

# Сохранение состояния выполнения в безопасном формате
save_state() {
  local step="$1"
  local state_file=".win11_creator_state"
  
  # Безопасно сохраняем состояние, экранируя значения переменных
  cat > "$state_file" << EOF
ISO_PATH="$(echo "$ISO_PATH" | sed 's/"/\\"/g')"
USB_DISK="$(echo "$USB_DISK" | sed 's/"/\\"/g')"
MOUNT_DIR="$(echo "$MOUNT_DIR" | sed 's/"/\\"/g')"
USB_MOUNT="$(echo "$USB_MOUNT" | sed 's/"/\\"/g')"
LAST_STEP="$step"
EOF
  
  # Проверяем, что файл создан успешно
  if [ -f "$state_file" ]; then
    log "INFO" "Состояние сохранено: $step"
    # Устанавливаем права только для текущего пользователя
    chmod 600 "$state_file" 2>/dev/null
  else
    log "WARNING" "Не удалось сохранить состояние"
  fi
}

# Восстановление загрузки после монтирования ISO
recover_mount_iso() {
  show_info_message "Попытка восстановления монтирования ISO..."
  
  # Проверяем, может быть образ уже смонтирован в другое место
  local iso_name=$(basename "$ISO_PATH")
  local mounted_volumes=$(hdiutil info | grep -i "$iso_name" | grep "/dev/disk")
  
  if [ -n "$mounted_volumes" ]; then
    local mounted_dev=$(echo "$mounted_volumes" | head -1 | awk '{print $1}')
    local mounted_path=$(hdiutil info | grep -A2 "$mounted_dev" | grep "/Volumes" | head -1 | awk '{print $1}')
    
    if [ -d "$mounted_path" ] && [ -n "$(ls -A "$mounted_path" 2>/dev/null)" ]; then
      show_success_message "ISO уже смонтирован в: $mounted_path"
      MOUNT_DIR="$mounted_path"
      return 0
    else
      # Образ смонтирован, но недоступен, предлагаем размонтировать
      show_warning_message "ISO смонтирован как $mounted_dev, но точка монтирования недоступна"
      printf "${WARNING}${BOLD}Попытаться размонтировать ISO? (Y/n): ${RESET}"
      read -r unmount_answer
      unmount_answer=$(echo "$unmount_answer" | tr '[:upper:]' '[:lower:]')
      
      if [ -z "$unmount_answer" ] || [ "$unmount_answer" = "y" ]; then
        echo -e "${INFO}Попытка размонтирования ISO...${RESET}"
        hdiutil unmount "$mounted_dev" -force 2>/dev/null
        if [ $? -eq 0 ]; then
          show_success_message "ISO успешно размонтирован"
        else
          show_error_message "Не удалось размонтировать ISO"
        fi
      fi
    fi
  fi
  
  # Проверяем, не занят ли ISO другими процессами
  local lsof_output=$(lsof "$ISO_PATH" 2>/dev/null)
  if [ -n "$lsof_output" ]; then
    show_warning_message "ISO-образ занят следующими процессами:"
    echo "$lsof_output"
    
    printf "${WARNING}${BOLD}Попытаться принудительно завершить эти процессы? (Y/n): ${RESET}"
    read -r kill_answer
    kill_answer=$(echo "$kill_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$kill_answer" ] || [ "$kill_answer" = "y" ]; then
      echo -e "${INFO}Завершение процессов...${RESET}"
      local pids=$(echo "$lsof_output" | awk 'NR>1 {print $2}' | sort -u)
      for pid in $pids; do
        echo -e "${INFO}Завершение процесса $pid...${RESET}"
        kill -9 $pid 2>/dev/null
      done
      
      # Даем время на освобождение ресурсов
      sleep 2
      
      # Проверяем снова
      lsof_output=$(lsof "$ISO_PATH" 2>/dev/null)
      if [ -n "$lsof_output" ]; then
        show_error_message "Не удалось освободить ISO-образ от всех процессов"
      else
        show_success_message "Все процессы, блокирующие ISO, завершены"
      fi
    fi
  fi
  
  # Создаем новую точку монтирования
  local new_mount_dir=$(mktemp -d)
  show_info_message "Пробуем монтировать в: $new_mount_dir"
  
  hdiutil mount "$ISO_PATH" -mountpoint "$new_mount_dir" -nobrowse
  
  if [ $? -eq 0 ] && [ -d "$new_mount_dir" ] && [ -n "$(ls -A "$new_mount_dir" 2>/dev/null)" ]; then
    show_success_message "ISO успешно смонтирован в: $new_mount_dir"
    MOUNT_DIR="$new_mount_dir"
    return 0
  else
    rm -rf "$new_mount_dir" 2>/dev/null
    
    # Последняя попытка с использованием автоматической точки монтирования
    show_info_message "Пробуем автоматическое монтирование..."
    hdiutil mount "$ISO_PATH"
    
    if [ $? -eq 0 ]; then
      # Ищем смонтированный образ
      local mounted_dev=$(hdiutil info | grep -i "$iso_name" | grep "/dev/disk" | head -1 | awk '{print $1}')
      local mounted_path=$(hdiutil info | grep -A2 "$mounted_dev" | grep "/Volumes" | head -1 | awk '{print $1}')
      
      if [ -d "$mounted_path" ] && [ -n "$(ls -A "$mounted_path" 2>/dev/null)" ]; then
        show_success_message "ISO успешно смонтирован в: $mounted_path"
        MOUNT_DIR="$mounted_path"
        return 0
      fi
    fi
    
    return 1
  fi
}

# Проверка свободного места перед копированием
check_free_space() {
  local source_path="$1"
  local dest_path="$2"
  
  # Получаем размер источника
  local source_size=0
  if [ -f "$source_path" ]; then
    source_size=$(du -sk "$source_path" | awk '{print $1}')
  elif [ -d "$source_path" ]; then
    source_size=$(du -sk "$source_path" | awk '{print $1}')
  else
    show_error_message "Некорректный путь источника: $source_path"
    return 1
  fi
  
  # Получаем свободное место на назначении
  local dest_free=$(df -k "$dest_path" | tail -1 | awk '{print $4}')
  
  # Требуем на 10% больше места
  local required_space=$(echo "$source_size * 1.1" | bc | awk '{print int($1)}')
  
  if [ $dest_free -lt $required_space ]; then
    show_error_message "Недостаточно места на диске назначения."
    draw_content_line "   - Требуется: $(echo "scale=2; $required_space/1024" | bc) МБ"
    draw_content_line "   - Доступно: $(echo "scale=2; $dest_free/1024" | bc) МБ"
    return 1
  fi
  
  show_success_message "Достаточно места на диске назначения"
  return 0
}

# ==================== ОСНОВНЫЕ ФУНКЦИИ ====================

# Справка по использованию скрипта
show_help() {
  clear_screen
  draw_fullscreen_box "Справка по Windows 11 USB Creator"
  
  echo
  show_info_message "Использование скрипта:"
  draw_content_line "   $0 [-i ISO_PATH] [-d DISK] [-n VOLUME_NAME] [-f] [-p NUM_PROCS] [-h]"
  
  echo
  local width=$(draw_info_block "Параметры")
  draw_block_line "-i ISO_PATH     Путь к ISO образу Windows 11"
  draw_block_line "-d DISK         Идентификатор диска (например, disk2)"
  draw_block_line "-n VOLUME_NAME  Имя тома для USB-накопителя"
  draw_block_line "-f              Быстрый режим (пропуск подтверждений и проверок)"
  draw_block_line "-p NUM_PROCS    Количество параллельных процессов при копировании"
  draw_block_line "-h              Показать эту справку"
  close_info_block
  
  echo
  show_info_message "Примеры использования:"
  draw_content_line "   $0 -i ~/Downloads/Win11.iso -d disk2 -n WIN11USB"
  draw_content_line "   $0 -i ~/Downloads/Win11.iso -d disk2 -p 8 -f"
  draw_content_line "   $0  # Интерактивный режим"
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для выхода]${RESET}"
  read
  exit 0
}

# Проверка необходимых утилит
check_requirements() {
  clear_screen
  draw_fullscreen_box "Проверка системных требований"
  
  local required_tools=("diskutil" "hdiutil" "rsync" "file" "mktemp" "sed" "awk" "grep")
  local missing_tools=()
  
  echo
  local width=$(draw_info_block "Проверка утилит")
  
  # Запускаем спиннер загрузки
  loading_spinner "Проверка системных компонентов..." 5
  
  # Имитация задержки проверки для демонстрации анимации
  sleep 1.5
  
  # Останавливаем спиннер
  stop_spinner
  
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      missing_tools+=("$tool")
      draw_block_line "[ ] ${ERROR}$tool${RESET} - не найден"
    else
      draw_block_line "[${SUCCESS}✓${RESET}] $tool - найден"
    fi
    sleep 0.2  # Красивая анимация последовательного появления строк
  done
  
  close_info_block
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo
    show_error_message "Не найдены утилиты: ${missing_tools[*]}"
    echo
    echo -e "${INFO}[Нажмите Enter для выхода]${RESET}"
    read
    exit 1
  else
    echo
    show_success_message "Все необходимые утилиты найдены"
  fi
  
  # Проверка запуска от имени администратора
  echo
  if [ "$(id -u)" -ne 0 ]; then
    show_warning_message "Скрипт запущен без прав администратора"
    draw_content_line "   ${WARNING}Для корректной работы рекомендуется запускать с sudo${RESET}"
    
    local continue_without_sudo=$(ask_yes_no "Продолжить без прав администратора?" "n")
    
    if [ "$continue_without_sudo" = "false" ]; then
      echo -e "${INFO}Перезапустите скрипт с sudo: ${ACCENT}sudo $0 $SCRIPT_ARGS${RESET}"
      exit 0
    fi
  else
    show_success_message "Скрипт запущен с правами администратора"
  fi
  
  # Системная информация
  local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "Неизвестно")
  local system_free_space=$(df -h / | tail -1 | awk '{print $4}')
  
  echo
  local width=$(draw_info_block "Системная информация")
  
  # Анимируем появление информации
  sleep 0.3
  draw_block_line "Версия macOS: ${ACCENT}$macos_version${RESET}"
  sleep 0.3
  draw_block_line "Свободное место на системном диске: ${ACCENT}$system_free_space${RESET}"
  
  close_info_block
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
}

# Выбор ISO образа - стильный дизайн
select_iso() {
  clear_screen
  draw_fullscreen_box "Выбор ISO образа Windows 11"
  
  # Найти все ISO файлы в текущем каталоге
  # Запускаем спиннер поиска файлов
  loading_spinner "Поиск ISO образов в текущей директории..." 10
  
  # Корректная обработка имен файлов с пробелами
  local iso_files=()
  # Сохраняем IFS и устанавливаем новый для корректной обработки пробелов
  OIFS="$IFS"
  IFS=$'\n'
  iso_files=($(find . -maxdepth 1 -name "*.iso" -type f | sort))
  IFS="$OIFS"
  
  # Останавливаем спиннер
  sleep 0.8
  stop_spinner
  
  echo
  if [ ${#iso_files[@]} -gt 0 ]; then
    local width=$(draw_info_block "Доступные ISO образы")
    
    for i in "${!iso_files[@]}"; do
      local file="${iso_files[$i]}"
      local filename=$(basename "$file")
      local filesize=$(du -h "$file" | cut -f1)
      
      draw_block_line "${ACCENT}$i)${RESET} ${WHITE}${filename}${RESET} (${INFO}${filesize}${RESET})"
      sleep 0.1  # Небольшая задержка для красивого эффекта появления
    done
    
    close_info_block
    echo
    
    # Получаем ввод пользователя - стильный дизайн
    local iso_choice=""
    printf "${INFO}${BOLD}Выберите номер файла или введите полный путь к ISO: ${RESET}"
    read -r iso_choice
    
    log "INFO" "Введен выбор ISO: '$iso_choice'"
    
    # Проверяем, что ввод - число и оно в пределах массива
    if [[ "$iso_choice" =~ ^[0-9]+$ ]] && [ "$iso_choice" -lt "${#iso_files[@]}" ]; then
      ISO_PATH="${iso_files[$iso_choice]}"
      ISO_PATH=$(realpath "$ISO_PATH" 2>/dev/null || echo "$ISO_PATH")
      log "INFO" "Выбран ISO по номеру: $iso_choice, путь: $ISO_PATH"
    else
      # Используем read -r для корректного обращения с путями, содержащими пробелы и спецсимволы
      ISO_PATH="$iso_choice"
      # Убираем возможные кавычки
      ISO_PATH="${ISO_PATH//\"/}"
      ISO_PATH="${ISO_PATH//\'/}"
      log "INFO" "Введен путь к ISO (после обработки): $ISO_PATH"
    fi
  else
    show_info_message "ISO файлы в текущей директории не найдены"
    printf "${INFO}${BOLD}Введите полный путь к ISO образу Windows 11: ${RESET}"
    read -r ISO_PATH
    log "INFO" "Введен путь к ISO: $ISO_PATH"
  fi
  
  # Проверяем существование файла
  if [ ! -f "$ISO_PATH" ]; then
    # Проверим путь с разными вариациями
    local paths_to_try=(
      "$ISO_PATH"
      "$(echo "$ISO_PATH" | xargs)"  # Путь без лишних пробелов
      "$(realpath "$ISO_PATH" 2>/dev/null || echo "")"  # Попытка преобразовать в абсолютный путь
      "$(dirname "$ISO_PATH" 2>/dev/null)/$(basename "$ISO_PATH" 2>/dev/null)"  # Разбор на компоненты
    )
    
    local found=false
    for try_path in "${paths_to_try[@]}"; do
      if [ -n "$try_path" ] && [ -f "$try_path" ]; then
        ISO_PATH="$try_path"
        found=true
        log "INFO" "Исправлен путь к ISO: $ISO_PATH"
        break
      fi
    done
    
    if [ "$found" = false ]; then
      # Файл действительно не найден, запрашиваем повторно
      show_error_message "Файл не найден: $ISO_PATH"
      log "ERROR" "Файл не найден: $ISO_PATH"
      
      # Упрощенный повторный запрос
      echo
      printf "${INFO}${BOLD}Введите корректный путь к ISO файлу (или 'exit' для выхода): ${RESET}"
      read -r iso_input
      log "DEBUG" "Повторный ввод пути к ISO: '$iso_input'"
      
      if [ "$iso_input" = "exit" ]; then
        exit 1
      fi
      
      ISO_PATH="$iso_input"
      
      # Повторная проверка существования файла
      if [ ! -f "$ISO_PATH" ]; then
        show_error_message "Файл снова не найден: $ISO_PATH"
        exit 1
      fi
    fi
  fi
  
  # Информация о выбранном ISO
  loading_spinner "Получение информации о ISO образе..." 10
  
  sleep 1.2
  
  local file_type=$(file -b "$ISO_PATH" 2>/dev/null || echo "Тип не определен")
  local is_iso=$(echo "$file_type" | grep -i "iso" || echo "")
  local iso_size=$(stat -f %z "$ISO_PATH" 2>/dev/null || echo "0")
  local iso_size_gb=$(echo "scale=2; $iso_size/1024/1024/1024" | bc 2>/dev/null || echo "Неизвестно")
  
  stop_spinner
  
  echo
  local width=$(draw_info_block "Информация о выбранном ISO")
  
  draw_block_line "Файл: ${ACCENT}$(basename "$ISO_PATH")${RESET}"
  sleep 0.2
  draw_block_line "Путь: ${ACCENT}$ISO_PATH${RESET}"
  sleep 0.2
  draw_block_line "Тип: ${ACCENT}$file_type${RESET}"
  sleep 0.2
  draw_block_line "Размер: ${ACCENT}${iso_size_gb} GB${RESET}"
  
  close_info_block
  
  if [ -z "$is_iso" ]; then
    echo
    show_warning_message "Файл не похож на ISO образ. Это может привести к ошибкам."
    
    printf "${WARNING}${BOLD}Продолжить с этим файлом? (y/N): ${RESET}"
    read -r continue_answer
    continue_answer=$(echo "$continue_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ "$continue_answer" != "y" ]; then
      select_iso
      return
    fi
  fi
  
  # Проверка, смонтирован ли уже ISO
  loading_spinner "Проверка, смонтирован ли уже ISO образ..." 10
  
  sleep 0.8
  local mounted_iso=$(hdiutil info 2>/dev/null | grep -i "$(basename "$ISO_PATH")" || echo "")
  stop_spinner
  
  if [ ! -z "$mounted_iso" ]; then
    # Получаем путь устройства
    local mounted_dev=$(echo "$mounted_iso" | grep -o "/dev/disk[0-9]*" | head -1)
    
    # Получаем реальную точку монтирования
    local mounted_dir=""
    mounted_dir=$(hdiutil info 2>/dev/null | grep -A1 "$mounted_dev" | tail -1 | awk '{print $1}')
    
    # Если не нашли, пробуем другим способом
    if [ ! -d "$mounted_dir" ]; then
      mounted_dir=$(df 2>/dev/null | grep "$mounted_dev" | awk '{print $NF}' | head -1)
    fi
    
    echo
    show_info_message "ISO образ уже смонтирован:"
    draw_content_line "   - Устройство: ${ACCENT}$mounted_dev${RESET}"
    draw_content_line "   - Точка монтирования: ${ACCENT}$mounted_dir${RESET}"
    
    printf "${INFO}${BOLD}Использовать существующую точку монтирования? (Y/n): ${RESET}"
    read -r use_existing_answer
    use_existing_answer=$(echo "$use_existing_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$use_existing_answer" ] || [ "$use_existing_answer" = "y" ]; then
      MOUNT_DIR="$mounted_dir"
      show_success_message "Будет использована существующая точка монтирования: $MOUNT_DIR"
    else
      show_info_message "Размонтирование существующего образа..."
      
      loading_spinner "Размонтирование образа..." 20
      
      hdiutil unmount "$mounted_dev" -force 2>/dev/null
      
      if [ $? -ne 0 ]; then
        stop_spinner "error"
        check_error "Не удалось размонтировать существующий образ"
      else
        sleep 0.8
        stop_spinner
      fi
      
      MOUNT_DIR=""
    fi
  else
    MOUNT_DIR=""
  fi
  
  # Сохраняем прогресс
  save_state "select_iso"
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
}

# Монтирование ISO образа (если ещё не смонтирован)
mount_iso() {
  # Пропускаем, если уже смонтирован
  if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
    # Проверяем, что точка монтирования действительно содержит файлы
    if [ "$(ls -A "$MOUNT_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
      return 0
    else
      show_warning_message "Точка монтирования существует, но может быть пустой: $MOUNT_DIR"
      MOUNT_DIR=""
    fi
  fi
  
  clear_screen
  draw_fullscreen_box "Монтирование ISO образа"
  
  echo
  show_info_message "Монтирование ISO образа: $(basename "$ISO_PATH")"
  
  # Проверка существования ISO-файла перед монтированием
  if [ ! -f "$ISO_PATH" ]; then
    show_error_message "ISO файл не найден: $ISO_PATH"
    handle_error 1 "ISO файл не найден: $ISO_PATH"
    exit 1
  fi
  
  # Создаем временную директорию для монтирования
  MOUNT_DIR=$(mktemp -d)
  draw_content_line "   - Временная директория: ${ACCENT}$MOUNT_DIR${RESET}"
  
  # Проверяем права на временную директорию
  if [ ! -w "$MOUNT_DIR" ]; then
    show_error_message "Нет прав на запись во временную директорию: $MOUNT_DIR"
    exit 1
  fi
  
  # Монтируем ISO образ
  echo
  echo -e "${INFO}${BOLD}Монтирование ISO образа...${RESET}"
  
  # Выводим прогресс-бар
  show_progress "Монтирование ISO"
  
  # Используем -nobrowse для предотвращения автоматического открытия в Finder
  hdiutil mount "$ISO_PATH" -mountpoint "$MOUNT_DIR" -nobrowse 2>/dev/null
  
  if [ $? -ne 0 ]; then
    show_error_message "Не удалось смонтировать ISO образ"
    
    # Попытка восстановления
    if recover_mount_iso; then
      show_success_message "ISO образ успешно смонтирован после восстановления"
    else
      # Дополнительная проверка, смонтирован ли образ автоматически в другое место
      loading_spinner "Поиск автоматического монтирования..." 10
      
      sleep 0.8
      local auto_mounted=$(hdiutil info 2>/dev/null | grep -i "$(basename "$ISO_PATH")" || echo "")
      stop_spinner
      
      if [ ! -z "$auto_mounted" ]; then
        local auto_mounted_dev=$(echo "$auto_mounted" | grep -o "/dev/disk[0-9]*" | head -1)
        local auto_mounted_dir=$(hdiutil info 2>/dev/null | grep -A1 "$auto_mounted_dev" | tail -1 | awk '{print $1}')
        
        if [ -d "$auto_mounted_dir" ] && [ "$(ls -A "$auto_mounted_dir" 2>/dev/null | wc -l)" -gt 0 ]; then
          show_info_message "Образ был автоматически смонтирован в: $auto_mounted_dir"
          MOUNT_DIR="$auto_mounted_dir"
        else
          echo
          echo -e "${INFO}[Нажмите Enter для выхода]${RESET}"
          read
          exit 1
        fi
      else
        echo
        echo -e "${INFO}[Нажмите Enter для выхода]${RESET}"
        read
        exit 1
      fi
    fi
  else
    show_success_message "ISO образ успешно смонтирован в: $MOUNT_DIR"
  fi
  
  # Проверка содержимого ISO
  echo
  loading_spinner "Проверка содержимого ISO образа..." 10
  
  sleep 1.5
  stop_spinner
  
  local width=$(draw_info_block "Проверка содержимого ISO образа")
  
  # Проверяем, что точка монтирования содержит файлы
  if [ "$(ls -A "$MOUNT_DIR" 2>/dev/null | wc -l)" -eq 0 ]; then
    draw_block_line "${ERROR}Точка монтирования пуста! ISO не смонтировался корректно.${RESET}"
    close_info_block
    
    show_error_message "Монтирование не удалось - точка монтирования пуста"
    echo
    echo -e "${INFO}[Нажмите Enter для выхода]${RESET}"
    read
    exit 1
  fi
  
  local essential_files=("sources/boot.wim" "bootmgr" "bootmgr.efi" "setup.exe")
  local all_files_present=true
  
  for file in "${essential_files[@]}"; do
    if [ -f "$MOUNT_DIR/$file" ]; then
      draw_block_line "[${SUCCESS}✓${RESET}] $file"
      sleep 0.2
    else
      draw_block_line "[${ERROR}✗${RESET}] $file - не найден"
      all_files_present=false
      sleep 0.2
    fi
  done
  
  close_info_block
  
  if [ "$all_files_present" = false ]; then
    echo
    show_warning_message "Отсутствуют важные файлы Windows. Возможны проблемы."
  else
    echo
    show_success_message "Все необходимые файлы Windows найдены"
  fi
  
  # Сохраняем прогресс
  save_state "mount_iso"
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
}

# Выбор USB накопителя
select_usb() {
  clear_screen
  draw_fullscreen_box "Выбор USB-накопителя"
  
  echo
  show_info_message "Вывод списка доступных дисков"
  echo
  
  # Обновляем кэш списка дисков
  rm -f "${CACHE_DIR}/disk_list" 2>/dev/null
  
  # Показываем список дисков с анимацией загрузки
  loading_spinner "Сканирование подключенных устройств..." 10
  
  sleep 1.5
  stop_spinner
  
  show_disk_list
  
  echo
  printf "${INFO}${BOLD}Введите идентификатор USB флешки (например, disk2): ${RESET}"
  read -r USB_DISK
  log "INFO" "Выбран USB диск: $USB_DISK"
  
  # Проверяем формат идентификатора диска
  if [[ ! "$USB_DISK" =~ ^disk[0-9]+$ ]]; then
    show_error_message "Некорректный идентификатор диска: $USB_DISK"
    
    printf "${WARNING}${BOLD}Хотите выбрать другой диск? (Y/n): ${RESET}"
    read -r retry_answer
    retry_answer=$(echo "$retry_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$retry_answer" ] || [ "$retry_answer" = "y" ]; then
      select_usb
      return
    else
      exit 1
    fi
  fi
  
  # Проверяем существование устройства
  if [ ! -e "/dev/$USB_DISK" ]; then
    show_error_message "Устройство не существует: /dev/$USB_DISK"
    
    printf "${WARNING}${BOLD}Хотите выбрать другой диск? (Y/n): ${RESET}"
    read -r retry_answer
    retry_answer=$(echo "$retry_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$retry_answer" ] || [ "$retry_answer" = "y" ]; then
      select_usb
      return
    else
      exit 1
    fi
  fi
  
  # Проверка, является ли выбранный диск системным
  loading_spinner "Проверка выбранного диска..." 10
  
  sleep 0.8
  
  # Дополнительная проверка системного диска
  local disk_info=$(diskutil info /dev/$USB_DISK 2>/dev/null || echo "")
  local is_internal=$(echo "$disk_info" | grep "Internal" | grep "Yes" || echo "")
  local boot_disk=$(diskutil list 2>/dev/null | grep "/ (Apple_APFS Container)" | grep "/dev/$USB_DISK" || echo "")
  
  stop_spinner
  
  # Дополнительная проверка на системный диск
  if [ ! -z "$boot_disk" ]; then
    echo
    show_error_message "${BLINK}ОПАСНО!${RESET} ${ERROR}Выбранный диск является системным диском!${RESET}"
    show_error_message "${ERROR}Форматирование системного диска невозможно! Выберите другой диск.${RESET}"
    
    printf "${WARNING}${BOLD}Хотите выбрать другой диск? (Y/n): ${RESET}"
    read -r retry_answer
    retry_answer=$(echo "$retry_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$retry_answer" ] || [ "$retry_answer" = "y" ]; then
      select_usb
      return
    else
      exit 1
    fi
  fi
  
  # Предупреждение для внутренних дисков
  if [ ! -z "$is_internal" ]; then
    echo
    show_warning_message "${BLINK}ВНИМАНИЕ!${RESET} ${ERROR}Выбранный диск похож на внутренний диск компьютера!${RESET}"
    show_warning_message "${ERROR}Форматирование приведет к потере всех данных на этом диске!${RESET}"
    echo
    
    printf "${WARNING}${BOLD}Введите ${ERROR}YES${WARNING} для подтверждения или что-угодно для отмены: ${RESET}"
    read -r confirm_internal
    
    if [ "$confirm_internal" != "YES" ]; then
      show_info_message "Операция отменена."
      
      printf "${INFO}${BOLD}Хотите выбрать другой диск? (Y/n): ${RESET}"
      read -r retry_answer
      retry_answer=$(echo "$retry_answer" | tr '[:upper:]' '[:lower:]')
      
      if [ -z "$retry_answer" ] || [ "$retry_answer" = "y" ]; then
        select_usb
        return
      else
        exit 0
      fi
    fi
  fi
  
  # Получаем информацию о диске
  loading_spinner "Получение информации о диске..." 10
  
  sleep 1.2
  local disk_info=$(diskutil info /dev/$USB_DISK 2>/dev/null || echo "Информация недоступна")
  local disk_size=$(echo "$disk_info" | grep "Disk Size" | awk '{print $3, $4}' || echo "Неизвестно")
  local disk_name=$(echo "$disk_info" | grep "Volume Name" | cut -d ':' -f2 | xargs || echo "")
  stop_spinner
  
  echo
  local width=$(draw_info_block "Информация о выбранном диске")
  
  draw_block_line "Диск: ${ACCENT}/dev/$USB_DISK${RESET}"
  sleep 0.2
  draw_block_line "Размер: ${ACCENT}$disk_size${RESET}"
  if [ -n "$disk_name" ]; then
    draw_block_line "Имя: ${ACCENT}$disk_name${RESET}"
  fi
  
  # Получаем текущее содержимое диска
  loading_spinner "Чтение содержимого диска..." 10
  
  sleep 0.8
  local disk_content=$(diskutil list /dev/$USB_DISK 2>/dev/null | tail -n +1 || echo "Информация недоступна")
  stop_spinner
  
  draw_block_line ""
  draw_block_line "Текущее содержимое:"
  
  while IFS= read -r line; do
    draw_block_line "$line"
    sleep 0.05  # Анимация быстрого появления строк
  done <<< "$disk_content"
  
  close_info_block
  
  # Подтверждение форматирования
  echo
  show_warning_message "${BLINK}ВНИМАНИЕ:${RESET} ${ERROR}Все данные на /dev/$USB_DISK будут удалены!${RESET}"
  
  printf "${WARNING}${BOLD}Вы уверены, что хотите продолжить? (y/N): ${RESET}"
  read -r confirm_format
  confirm_format=$(echo "$confirm_format" | tr '[:upper:]' '[:lower:]')
  
  if [ "$confirm_format" != "y" ]; then
    show_info_message "Операция отменена."
    
    printf "${INFO}${BOLD}Хотите выбрать другой диск? (Y/n): ${RESET}"
    read -r retry_answer
    retry_answer=$(echo "$retry_answer" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$retry_answer" ] || [ "$retry_answer" = "y" ]; then
      select_usb
      return
    else
      exit 0
    fi
  fi
  
  # Сохраняем прогресс
  save_state "select_usb"
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
}

# Подготовка USB накопителя
prepare_usb() {
  clear_screen
  draw_fullscreen_box "Подготовка USB-накопителя"
  
  echo
  show_info_message "Подготовка USB-накопителя /dev/$USB_DISK"
  
  # Проверяем существование устройства перед работой с ним
  if [ ! -e "/dev/$USB_DISK" ]; then
    show_error_message "Устройство не существует: /dev/$USB_DISK"
    exit 1
  fi
  
  # Размонтируем диск
  echo
  echo -e "${INFO}${BOLD}Размонтирование диска...${RESET}"
  
  loading_spinner "Размонтирование диска..." 20
  
  diskutil unmountDisk /dev/$USB_DISK &>/dev/null
  
  if [ $? -ne 0 ]; then
    stop_spinner "error"
    # Попытка принудительного размонтирования
    echo -e "${WARNING}Попытка принудительного размонтирования...${RESET}"
    diskutil unmountDisk force /dev/$USB_DISK &>/dev/null
    
    if [ $? -ne 0 ]; then
      show_error_message "Не удалось размонтировать диск. Возможно, он используется другими программами."
      exit 1
    fi
  else
    sleep 0.8
    stop_spinner
    show_success_message "Диск успешно размонтирован"
  fi
  
  # Форматируем флешку в exFAT (только эта опция)
  echo
  printf "${INFO}${BOLD}Введите имя для USB-накопителя ${RESET}[${ACCENT}WINDOWS11${RESET}]: "
  read -r volume_name
  if [ -z "$volume_name" ]; then
    volume_name="WINDOWS11"
  fi
  log "INFO" "Имя тома для USB: $volume_name"
  
  # Удаляем недопустимые символы из имени тома
  volume_name=$(echo "$volume_name" | tr -cd 'A-Za-z0-9._-')
  
  echo
  echo -e "${INFO}${BOLD}Форматирование флешки в exFAT...${RESET}"
  draw_content_line "   - Имя тома: ${ACCENT}$volume_name${RESET}"
  
  # Запускаем форматирование с прогресс-баром
  show_progress "Форматирование USB"
  
  diskutil eraseDisk ExFAT "$volume_name" /dev/$USB_DISK &>/dev/null
  
  if [ $? -ne 0 ]; then
    show_error_message "Не удалось отформатировать диск"
    
    # Попытка альтернативного форматирования
    echo -e "${INFO}Пробуем альтернативный метод форматирования...${RESET}"
    diskutil partitionDisk /dev/$USB_DISK 1 GPT ExFAT "$volume_name" 100% &>/dev/null
    
    if [ $? -ne 0 ]; then
      show_error_message "Альтернативное форматирование также не удалось"
      exit 1
    else
      show_success_message "Флешка успешно отформатирована с помощью альтернативного метода"
    fi
  else
    show_success_message "Флешка успешно отформатирована"
  fi
  
  # Явно монтируем диск после форматирования
  echo
  echo -e "${INFO}${BOLD}Монтирование отформатированной флешки...${RESET}"
  
  loading_spinner "Монтирование диска..." 20
  
  diskutil mountDisk /dev/$USB_DISK &>/dev/null
  
  if [ $? -ne 0 ]; then
    stop_spinner "error"
    # Попытка монтировать первый раздел
    echo -e "${WARNING}Попытка монтирования первого раздела...${RESET}"
    diskutil mount /dev/${USB_DISK}s1 &>/dev/null
    
    if [ $? -ne 0 ]; then
      show_error_message "Не удалось монтировать флешку"
      exit 1
    fi
  else
    sleep 0.8
    stop_spinner
  fi
  
  # Даем системе время на монтирование
  sleep 3
  
  # Обновим кэш сведений о дисках
  rm -f "${CACHE_DIR}/disk_list" 2>/dev/null
  
  # Более надежное определение точки монтирования
  echo
  echo -e "${INFO}${BOLD}Определение точки монтирования...${RESET}"
  
  # Список методов определения точки монтирования
  loading_spinner "Анализ точек монтирования..." 10
  
  sleep 1.2
  stop_spinner
  
  echo -e "${INFO}Попытка найти точку монтирования с помощью разных методов...${RESET}"
  
  # Функция для проверки монтирования
  verify_mount_point() {
    local mount_point="$1"
    if [ -n "$mount_point" ] && [ -d "$mount_point" ] && [ -w "$mount_point" ]; then
      return 0  # Точка монтирования существует и доступна для записи
    fi
    return 1  # Точка монтирования недоступна
  }
  
  # Метод 1: По имени тома
  USB_MOUNT=$(df 2>/dev/null | grep -i "$volume_name" | awk '{print $9}' || echo "")
  draw_content_line "   - По имени тома: ${ACCENT}$USB_MOUNT${RESET}"
  
  # Метод 2: По идентификатору диска (первый раздел)
  if ! verify_mount_point "$USB_MOUNT"; then
    local mount1=$(diskutil info /dev/${USB_DISK}s1 2>/dev/null | grep "Mount Point" | cut -d ':' -f2 | xargs || echo "")
    draw_content_line "   - По идентификатору диска (s1): ${ACCENT}$mount1${RESET}"
    if verify_mount_point "$mount1"; then
      USB_MOUNT="$mount1"
    fi
  fi
  
  # Метод 3: По идентификатору диска (второй раздел)
  if ! verify_mount_point "$USB_MOUNT"; then
    local mount2=$(diskutil info /dev/${USB_DISK}s2 2>/dev/null | grep "Mount Point" | cut -d ':' -f2 | xargs || echo "")
    draw_content_line "   - По идентификатору диска (s2): ${ACCENT}$mount2${RESET}"
    if verify_mount_point "$mount2"; then
      USB_MOUNT="$mount2"
    fi
  fi
  
  # Метод 4: Через df, поиск по диску
  if ! verify_mount_point "$USB_MOUNT"; then
    local mount4=$(df 2>/dev/null | grep "/dev/${USB_DISK}" | awk '{print $9}' || echo "")
    draw_content_line "   - Через df по диску: ${ACCENT}$mount4${RESET}"
    if verify_mount_point "$mount4"; then
      USB_MOUNT="$mount4"
    fi
  fi
  
  # Метод 5: Предполагаемый путь
  if ! verify_mount_point "$USB_MOUNT"; then
    local mount5="/Volumes/$volume_name"
    draw_content_line "   - Предполагаемый путь: ${ACCENT}$mount5${RESET}"
    if verify_mount_point "$mount5"; then
      USB_MOUNT="$mount5"
    fi
  fi
  
  # Если все ещё не нашли или точка монтирования недоступна, запрашиваем у пользователя
  if ! verify_mount_point "$USB_MOUNT"; then
    echo
    show_warning_message "Не удалось автоматически определить точку монтирования"
    printf "${INFO}${BOLD}Введите путь к примонтированной флешке ${RESET}[${ACCENT}/Volumes/$volume_name${RESET}]: "
    read -r manual_mount
    if [ -z "$manual_mount" ]; then
      USB_MOUNT="/Volumes/$volume_name"
    else
      USB_MOUNT="$manual_mount"
    fi
    log "INFO" "Ручной ввод точки монтирования: $USB_MOUNT"
  fi
  
  # Финальная проверка
  if ! verify_mount_point "$USB_MOUNT"; then
    show_error_message "Путь к флешке не найден или недоступен: $USB_MOUNT"
    show_info_message "Попробуйте отмонтировать и смонтировать флешку вручную, затем укажите путь"
    
    printf "${INFO}${BOLD}Введите путь к флешке вручную или 'exit' для выхода: ${RESET}"
    read -r mount_manual
    if [ "$mount_manual" = "exit" ]; then
      exit 1
    elif [ -d "$mount_manual" ]; then
      USB_MOUNT="$mount_manual"
    else
      show_error_message "Указанный путь недоступен: $mount_manual"
      exit 1
    fi
  fi
  
  show_success_message "Флешка примонтирована в: $USB_MOUNT"
  
  # Проверка свободного места и прав записи
  loading_spinner "Проверка прав доступа..." 5
  
  sleep 0.8
  stop_spinner
  
  if [ -w "$USB_MOUNT" ]; then
    local flash_free_space=$(df -h "$USB_MOUNT" 2>/dev/null | tail -1 | awk '{print $4}' || echo "Неизвестно")
    draw_content_line "   - Свободное место: ${ACCENT}$flash_free_space${RESET}"
    draw_content_line "   - Права на запись: ${SUCCESS}есть${RESET}"
    
    # Проверка свободного места по сравнению с размером ISO
    local iso_size=$(stat -f %z "$ISO_PATH" 2>/dev/null || echo "0")
    local flash_free_kb=$(df -k "$USB_MOUNT" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    local iso_size_mb=$((iso_size / 1024 / 1024))
    local flash_free_mb=$((flash_free_kb / 1024))
    
    if [ $flash_free_mb -lt $iso_size_mb ]; then
      show_warning_message "Недостаточно места на флешке! Требуется: ${iso_size_mb}MB, доступно: ${flash_free_mb}MB"
      printf "${WARNING}${BOLD}Продолжить, несмотря на нехватку места? (y/N): ${RESET}"
      read -r continue_anyway
      continue_anyway=$(echo "$continue_anyway" | tr '[:upper:]' '[:lower:]')
      
      if [ "$continue_anyway" != "y" ]; then
        echo -e "${INFO}Операция отменена. Попробуйте использовать другую флешку.${RESET}"
        exit 1
      fi
    fi
  else
    show_error_message "Нет прав на запись в $USB_MOUNT"
    exit 1
  fi
  
  # Сохраняем прогресс
  save_state "prepare_usb"
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
}

# Копирование файлов
copy_files() {
  clear_screen
  draw_fullscreen_box "Копирование файлов Windows 11"
  
  echo
  show_info_message "Копирование файлов Windows 11 на флешку"
  draw_content_line "   - Из: ${ACCENT}$MOUNT_DIR${RESET}"
  draw_content_line "   - В: ${ACCENT}$USB_MOUNT${RESET}"
  
  echo
  show_warning_message "${BLINK}Не отключайте USB-накопитель во время копирования!${RESET}"
  show_warning_message "Этот процесс может занять 10-30 минут в зависимости от скорости USB"
  
  # Дополнительная проверка исходной и целевой директорий
  loading_spinner "Проверка директорий перед копированием..." 10
  
  sleep 1.2
  
  if [ ! -d "$MOUNT_DIR" ]; then
    stop_spinner "error"
    show_error_message "Директория с ISO образом не найдена: $MOUNT_DIR"
    exit 1
  fi
  
  # Проверяем, что точка монтирования ISO содержит файлы
  if [ "$(ls -A "$MOUNT_DIR" 2>/dev/null | wc -l)" -eq 0 ]; then
    stop_spinner "error"
    show_error_message "Точка монтирования ISO пуста: $MOUNT_DIR"
    draw_content_line "Содержимое точки монтирования:"
    ls -la "$MOUNT_DIR"
    exit 1
  fi
  
  if [ ! -d "$USB_MOUNT" ]; then
    stop_spinner "error"
    show_error_message "Директория флешки не найдена: $USB_MOUNT"
    exit 1
  fi
  
  # Проверяем права на запись
  if [ ! -w "$USB_MOUNT" ]; then
    stop_spinner "error"
    show_error_message "Нет прав на запись в директорию флешки: $USB_MOUNT"
    exit 1
  fi
  
  # Проверка достаточного места на флешке
  if ! check_free_space "$MOUNT_DIR" "$USB_MOUNT"; then
    stop_spinner "error"
    show_error_message "Недостаточно места на флешке для копирования файлов"
    exit 1
  fi
  
  stop_spinner
  
  # Запуск копирования
  echo
  echo -e "${INFO}${BOLD}Копирование файлов...${RESET}"
  echo
  
  # Листинг содержимого источника
  local width=$(draw_info_block "Содержимое ISO образа (первые 10 файлов)")
  
  ls -la "$MOUNT_DIR" | head -n 10 | while IFS= read -r line; do
    draw_block_line "$line"
    sleep 0.05
  done
  
  if [ "$(ls -la "$MOUNT_DIR" | wc -l)" -gt 10 ]; then
    draw_block_line "${INFO}... и еще файлы (показаны первые 10)${RESET}"
  fi
  
  close_info_block
  echo
  
  # Используем rsync с улучшенными параметрами для стабильности и производительности
  echo -e "${INFO}Запуск копирования... Это займет некоторое время. Пожалуйста, подождите.${RESET}"
  echo
  
  # Создаем файл индикации, чтобы определять прогресс копирования
  local progress_file="${CACHE_DIR}/copy_progress"
  rm -f "$progress_file" 2>/dev/null
  
  # Функция для обработки вывода rsync и сохранения прогресса
  process_rsync_output() {
    while IFS= read -r line; do
      echo "$line" > "$progress_file"
      echo "$line"
    done
  }
  
  # Запускаем копирование с совместимыми параметрами
  rsync -av --progress --stats --copy-links --no-perms "$MOUNT_DIR/" "$USB_MOUNT/" 2>&1 | process_rsync_output
  
  # Проверка результата копирования
  local copy_result=$?
  
  if [ $copy_result -ne 0 ]; then
    show_error_message "Ошибка при копировании файлов (код: $copy_result)"
    
    # Проверка ошибок более подробно
    echo -e "${WARNING}Проверка возможных причин ошибки:${RESET}"
    
    if [ ! -r "$MOUNT_DIR" ]; then
      draw_content_line "- ${ERROR}Нет прав на чтение из $MOUNT_DIR${RESET}"
    fi
    
    if [ ! -w "$USB_MOUNT" ]; then
      draw_content_line "- ${ERROR}Нет прав на запись в $USB_MOUNT${RESET}"
    fi
    
    draw_content_line "- ${WARNING}Проверьте, не отключилась ли флешка во время копирования${RESET}"
    
    # Сохраняем файл с деталями ошибки
    local error_log="${LOG_FILE%.log}_rsync_error.log"
    echo "Копирование завершилось с ошибкой $copy_result в $(date)" > "$error_log"
    echo "Возможно, некоторые файлы не были скопированы" >> "$error_log"
    
    draw_content_line "- ${INFO}Детали ошибки сохранены в: $error_log${RESET}"
    
    # Предлагаем продолжить копирование вручную
    echo -e "${INFO}Попробуйте выполнить копирование вручную:${RESET}"
    echo -e "cp -R \"$MOUNT_DIR/\" \"$USB_MOUNT/\""
    
    echo
    echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
    read
    exit 1
  else
    echo
    show_success_message "Копирование файлов успешно завершено"
    
    # Принудительно сбрасываем буферы на диск
    sync
  fi
  
  # Проверка наличия важных файлов на флешке
  echo
  loading_spinner "Проверка скопированных файлов..." 10
  
  sleep 1.5
  stop_spinner
  
  local width=$(draw_info_block "Проверка скопированных файлов")
  
  local essential_files=("bootmgr" "bootmgr.efi" "setup.exe" "sources/boot.wim")
  local all_files_present=true
  
  for file in "${essential_files[@]}"; do
    if [ -f "$USB_MOUNT/$file" ]; then
      draw_block_line "[${SUCCESS}✓${RESET}] $file"
    else
      draw_block_line "[${ERROR}✗${RESET}] $file - не найден"
      all_files_present=false
    fi
    sleep 0.2
  done
  
  close_info_block
  
  if [ "$all_files_present" = false ]; then
    echo
    show_warning_message "Отсутствуют некоторые файлы. Флешка может не загрузиться корректно."
  else
    echo
    show_success_message "Все необходимые файлы успешно скопированы!"
  fi
  
  # Сохраняем прогресс
  save_state "copy_files"
  
  close_fullscreen_box
  
  echo
  echo -e "${INFO}[Нажмите Enter для продолжения]${RESET}"
  read
}

# Завершение создания флешки
finish() {
  clear_screen
  draw_fullscreen_box "Завершение создания загрузочной флешки"
  
  echo
  loading_spinner "Финализация..." 5
  
  sleep 1.5
  stop_spinner
  
  local width=$(draw_info_block "Итоги операции")
  
  draw_block_line "[${SUCCESS}✓${RESET}] ISO образ: ${ACCENT}$(basename "$ISO_PATH")${RESET}"
  sleep 0.3
  draw_block_line "[${SUCCESS}✓${RESET}] USB-накопитель: ${ACCENT}/dev/$USB_DISK${RESET}"
  sleep 0.3
  draw_block_line "[${SUCCESS}✓${RESET}] Точка монтирования: ${ACCENT}$USB_MOUNT${RESET}"
  
  close_info_block
  
  # Размонтирование ISO образа (если мы его монтировали)
  if [ -n "$MOUNT_DIR" ] && [ "$MOUNT_DIR" != "/dev/disk"* ] && [ "$MOUNT_DIR" != "/Volumes/"* ]; then
    echo
    echo -e "${INFO}${BOLD}Размонтирование ISO образа...${RESET}"
    
    loading_spinner "Размонтирование ISO образа..." 10
    
    hdiutil unmount "$MOUNT_DIR" -force 2>/dev/null
    
    # Очистка временной директории
    rm -rf "$MOUNT_DIR" 2>/dev/null
    
    sleep 0.8
    stop_spinner
    
    show_success_message "ISO образ размонтирован"
  fi
  
  # Спрашиваем, нужно ли извлечь флешку
  echo
  printf "${INFO}${BOLD}Хотите безопасно извлечь флешку? (Y/n): ${RESET}"
  read -r eject_answer
  eject_answer=$(echo "$eject_answer" | tr '[:upper:]' '[:lower:]')
  
  if [ -z "$eject_answer" ] || [ "$eject_answer" = "y" ]; then
    echo
    echo -e "${INFO}${BOLD}Извлечение флешки...${RESET}"
    
    loading_spinner "Безопасное извлечение флешки..." 15
    
    # Сначала принудительно завершаем все процессы, связанные с диском
    pkill -f "$USB_DISK" 2>/dev/null
    
    # Даем время на завершение процессов
    sleep 1
    
    # Сбрасываем буферы на диск
    sync
    
    # Извлекаем диск
    diskutil eject /dev/$USB_DISK &>/dev/null
    
    sleep 0.8
    stop_spinner
    
    if [ $? -eq 0 ]; then
      show_success_message "Флешка успешно извлечена"
    else
      show_warning_message "Не удалось извлечь флешку. Сделайте это вручную через Finder."
    fi
  fi
  
  # Советы по установке Windows 11
  echo
  local width=$(draw_info_block "Советы по установке Windows 11")
  
  draw_block_line "${ACCENT}1. Загрузка с USB:${RESET}"
  sleep 0.2
  draw_block_line "   - Перезагрузите компьютер и нажмите ${WARNING}F12${RESET} для выбора устройства"
  sleep 0.2
  draw_block_line "   - Выберите вашу USB флешку из списка"
  sleep 0.2
  draw_block_line ""
  
  draw_block_line "${ACCENT}2. Обход требований TPM 2.0:${RESET}"
  sleep 0.2
  draw_block_line "   - Нажмите ${WARNING}Shift+F10${RESET} для вызова командной строки"
  sleep 0.2
  draw_block_line "   - Запустите ${WARNING}regedit${RESET}"
  sleep 0.2
  draw_block_line "   - Создайте раздел ${WARNING}HKLM\\SYSTEM\\Setup\\LabConfig${RESET}"
  sleep 0.2
  draw_block_line "   - Добавьте параметры DWORD: ${WARNING}BypassTPMCheck=1${RESET},"
  sleep 0.2
  draw_block_line "     ${WARNING}BypassSecureBootCheck=1${RESET}, ${WARNING}BypassRAMCheck=1${RESET}"
  sleep 0.2
  draw_block_line ""
  
  draw_block_line "${ACCENT}3. После установки:${RESET}"
  sleep 0.2
  draw_block_line "   - Установите драйверы с сайта Dell"
  sleep 0.2
  draw_block_line "   - Выполните все обновления Windows"
  sleep 0.2
  draw_block_line ""
  
  draw_block_line "${SUCCESS}${BOLD}Удачной установки!${RESET}"
  
  close_info_block
  
  # Удаление файла состояния
  rm -f ".win11_creator_state" 2>/dev/null
  
  # Очистка временных файлов
  rm -rf "$CACHE_DIR" 2>/dev/null
  
  close_fullscreen_box
  
  echo
  echo -e "${SUCCESS}${BOLD}====== СОЗДАНИЕ ЗАГРУЗОЧНОЙ ФЛЕШКИ WINDOWS 11 ЗАВЕРШЕНО! ======${RESET}"
  echo -e "${INFO}Лог операции сохранён в: ${ACCENT}$LOG_FILE${RESET}"
  
  echo
  echo -e "${ACCENT}[Нажмите Enter для выхода]${RESET}"
  read
  
  clear_screen
  
  # Финальный аккорд - анимация завершения
  for ((i=0; i<3; i++)); do
    clear_screen
    echo ""
    echo ""
    echo -e "$(center_text "${SUCCESS}${BOLD}Спасибо за использование Windows 11 USB Creator!${RESET}")"
    echo ""
    echo -e "$(center_text "${PRIMARY}Создано с ${ACCENT}♥${PRIMARY} для Dell OptiPlex 3070 Micro${RESET}")"
    echo ""
    sleep 0.5
    
    clear_screen
    echo ""
    echo ""
    echo -e "$(center_text "${SUCCESS}${BOLD}Thanks for using Windows 11 USB Creator!${RESET}")"
    echo ""
    echo -e "$(center_text "${PRIMARY}Created with ${ACCENT}♥${PRIMARY} for Dell OptiPlex 3070 Micro${RESET}")"
    echo ""
    sleep 0.5
  done
  
  # Удаляем trap перед выходом
  trap - INT TERM EXIT
  
  exit 0
}

# ==================== ОБРАБОТКА АРГУМЕНТОВ КОМАНДНОЙ СТРОКИ ====================
SCRIPT_ARGS="$@"  # Сохраняем аргументы для возможного перезапуска с sudo
FAST_MODE=false
PARALLEL_JOBS=0

# Показываем справку при необходимости
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  show_help
  exit 0
fi

# Обработка параметров командной строки
while getopts "i:d:n:fp:h" opt; do
  case $opt in
    i) ISO_PATH="$OPTARG" ;;
    d) USB_DISK="$OPTARG" ;;
    n) volume_name="$OPTARG" ;;
    f) FAST_MODE=true ;;
    p) PARALLEL_JOBS="$OPTARG" ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done

# ==================== ПРОВЕРКА ПРЕДЫДУЩЕЙ СЕССИИ ====================
if [ -f ".win11_creator_state" ]; then
  clear_screen
  echo -e "${INFO}${BOLD}Найдена предыдущая незавершенная сессия.${RESET}"
  printf "${INFO}${BOLD}Хотите продолжить с предыдущего места? (Y/n): ${RESET}"
  read -r resume_answer
  resume_answer=$(echo "$resume_answer" | tr '[:upper:]' '[:lower:]')
  
  if [ -z "$resume_answer" ] || [ "$resume_answer" = "y" ]; then
    # Проверяем файл на безопасность перед загрузкой
    if grep -q -E "^(ISO_PATH|USB_DISK|MOUNT_DIR|USB_MOUNT|LAST_STEP)=" ".win11_creator_state"; then
      # Загружаем только известные переменные, безопасно
      ISO_PATH=$(grep "^ISO_PATH=" ".win11_creator_state" | cut -d= -f2- | sed 's/^"//;s/"$//')
      USB_DISK=$(grep "^USB_DISK=" ".win11_creator_state" | cut -d= -f2- | sed 's/^"//;s/"$//')
      MOUNT_DIR=$(grep "^MOUNT_DIR=" ".win11_creator_state" | cut -d= -f2- | sed 's/^"//;s/"$//')
      USB_MOUNT=$(grep "^USB_MOUNT=" ".win11_creator_state" | cut -d= -f2- | sed 's/^"//;s/"$//')
      LAST_STEP=$(grep "^LAST_STEP=" ".win11_creator_state" | cut -d= -f2- | sed 's/^"//;s/"$//')
      
      # Выполняем проверки безопасности
      if [[ "$ISO_PATH" == *";"* || "$USB_DISK" == *";"* || "$MOUNT_DIR" == *";"* || "$USB_MOUNT" == *";"* || "$LAST_STEP" == *";"* ]]; then
        show_error_message "Файл состояния содержит подозрительные символы. Запуск отменен."
        log "ERROR" "Подозрительный файл состояния. Возможная попытка внедрения кода."
        rm -f ".win11_creator_state"
        exit 1
      fi
      
      # Проверяем существование путей
      if [ -n "$ISO_PATH" ] && [ ! -f "$ISO_PATH" ]; then
        show_warning_message "ISO файл не найден: $ISO_PATH"
        ISO_PATH=""
      fi
      
      if [ -n "$MOUNT_DIR" ] && [ ! -d "$MOUNT_DIR" ]; then
        show_warning_message "Точка монтирования не существует: $MOUNT_DIR"
        MOUNT_DIR=""
      fi
      
      if [ -n "$USB_MOUNT" ] && [ ! -d "$USB_MOUNT" ]; then
        show_warning_message "Точка монтирования USB не существует: $USB_MOUNT"
        USB_MOUNT=""
      fi
      
      # Продолжаем с последнего шага
      case "$LAST_STEP" in
        "select_iso") 
          check_requirements
          mount_iso
          select_usb
          prepare_usb
          copy_files
          finish
          ;;
        "mount_iso") 
          check_requirements
          select_usb
          prepare_usb
          copy_files
          finish
          ;;
        "select_usb") 
          check_requirements
          prepare_usb
          copy_files
          finish
          ;;
        "prepare_usb") 
          check_requirements
          copy_files
          finish
          ;;
        "copy_files") 
          check_requirements
          finish
          ;;
        *) 
          # Если не удалось определить шаг, начинаем сначала
          show_warning_message "Не удалось определить последний шаг, начинаем сначала"
          ;;
      esac
    else
      show_error_message "Формат файла состояния некорректен. Запуск отменен."
      log "ERROR" "Некорректный файл состояния."
      rm -f ".win11_creator_state"
    fi
  fi
fi

# ==================== ГЛАВНАЯ ПРОГРАММА ====================

clear_screen
log "INFO" "Запуск скрипта создания загрузочной флешки Windows 11 (версия $VERSION)"

# Проверка системных зависимостей
check_system_dependencies

# Показать заставку
show_splash

# Проверяем наличие предыдущей сессии напрямую
resume_previous_session

# Основной процесс создания загрузочной флешки
select_iso
mount_iso
select_usb
prepare_usb
copy_files
finish

# Удаляем trap перед выходом
trap - INT TERM EXIT

exit 0