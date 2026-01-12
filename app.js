import { checkSession, onAuthStateChange, sendMagicLink, logout } from './auth.js';
import { showTasks, hideTasksSection } from './tasks.js';
import { log } from './Logger.js';


(async () => {
    const authSection = document.getElementById('auth-section');
    const tasksSection = document.getElementById('tasks-section');
    const emailInput = document.getElementById('email');
    const sendMagicLinkBtn = document.getElementById('send-magic-link');
    const authMessage = document.getElementById('auth-message');
    const tasksList = document.getElementById('tasks-list');
    const logoutBtn = document.getElementById('logout-btn');

    // Check if user is already authenticated
    const session = await checkSession();
    if (session) {
        showTasks(authSection, tasksSection, tasksList);
    }

    // Listen for auth changes
    log.debug('event: ' || event);
    log.debug('session: ' || session);
    onAuthStateChange((event, session) => {
        log.in();
        log.debug('app');
        log.debug('event: ' || event);
        log.debug('session: ' || session);
        if (event === 'SIGNED_IN' && session) {
            showTasks(authSection, tasksSection, tasksList);
        } else if (event === 'SIGNED_OUT') {
            hideTasksSection(authSection, tasksSection);
            tasksList.innerHTML = '';
        }
        log.out();
    });

    sendMagicLinkBtn.addEventListener('click', async () => {
        const email = emailInput.value.trim();
        if (!email) {
            authMessage.textContent = 'Введите email';
            return;
        }

        try {
            await sendMagicLink(email);
            authMessage.textContent = 'Magic link отправлен на ваш email. Проверьте почту.';
        } catch (error) {
            authMessage.textContent = 'Ошибка: ' + error.message;
        }
    });

    logoutBtn.addEventListener('click', async () => {
        try {
            await logout();
            hideTasksSection(authSection, tasksSection);
            tasksList.innerHTML = '';
        } catch (error) {
            log.error('Ошибка при выходе:', error);
        }
    });
})();
