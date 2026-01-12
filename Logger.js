const getTimestamp = () => {
    const now = new Date();
    return `${now.getHours().toString().padStart(2, '0')}:` +
           `${now.getMinutes().toString().padStart(2, '0')}:` +
           `${now.getSeconds().toString().padStart(2, '0')}.` +
           `${now.getMilliseconds().toString().padStart(3, '0')}`;
};

// Получаем имя вызывающей функции
const getCallerInfo = () => {
    try {
        throw new Error();
    } catch (e) {
        const stackLines = e.stack.split('\n');
        // Обычно нужна 4-я строка (0: getCallerInfo, 1: логгер, 2: вызывающая функция, 3: ее caller)
        const callerLine = stackLines[3] || stackLines[2] || '';
        
        // Извлекаем имя функции из строки стека
        const match = callerLine.match(/at (\S+)/);
        if (match) {
            return match[1];
        }
        
        // Или извлекаем из анонимной функции/метода класса
        const classMethodMatch = callerLine.match(/at (\w+)\.(\w+)/);
        if (classMethodMatch) {
            return `${classMethodMatch[1]}.${classMethodMatch[2]}`;
        }
        
        return 'anonymous';
    }
};

const emojis = {
    info: 'ℹ️',
    warn: '⚠️', 
    error: '❌',
    debug: '🔍',
    in: '▶️',
    out: '⏹️'
};

export const log = {
    info: (...args) => console.log(
        `%c[${getTimestamp()}] ${emojis.info}  INFO %c[${getCallerInfo()}]`, 
        'color: #34c759; font-weight: bold;',
        'color: #5856d6; font-style: italic;',
        ...args
    ),
    warn: (...args) => console.warn(
        `%c[${getTimestamp()}] ${emojis.warn}  WARN %c[${getCallerInfo()}]`, 
        'color: #ff9500; font-weight: bold;',
        'color: #5856d6; font-style: italic;',
        ...args
    ),
    error: (...args) => console.error(
        `%c[${getTimestamp()}] ${emojis.error} ERROR %c[${getCallerInfo()}]`, 
        'color: #ff3b30; font-weight: bold;',
        'color: #5856d6; font-style: italic;',
        ...args
    ),
    debug: (...args) => {
        if (window.location.hostname === 'localhost' || 
            window.location.hostname === '127.0.0.1') {
            console.debug(
                `%c[${getTimestamp()}] ${emojis.debug} DEBUG %c[${getCallerInfo()}]`, 
                'color: #8e8e93; font-style: italic;',
                'color: #5856d6; font-style: italic;',
                ...args
            );
        }
    },
    in: (...args) => {
        if (window.location.hostname === 'localhost' || 
            window.location.hostname === '127.0.0.1') {
            console.debug(
                `%c[${getTimestamp()}] ${emojis.in}    IN %c[${getCallerInfo()}]`, 
                'color: #8e8e93; font-style: italic;',
                'color: #5856d6; font-style: italic;',
                ...args
            );
        }
    },
    out: (...args) => {
        if (window.location.hostname === 'localhost' || 
            window.location.hostname === '127.0.0.1') {
            console.debug(
                `%c[${getTimestamp()}] ${emojis.out}   OUT %c[${getCallerInfo()}]`, 
                'color: #8e8e93; font-style: italic;',
                'color: #5856d6; font-style: italic;',
                ...args
            );
        }
    }
};