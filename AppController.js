import { AuthManager } from './AuthManager.js';
import { TaskManager } from './TaskManager.js';
import { log } from './Logger.js';

export class App {
    constructor() {
        this.authSection = document.getElementById('auth-section');
        this.tasksSection = document.getElementById('tasks-section');
        this.emailInput = document.getElementById('email');
        this.sendMagicLinkBtn = document.getElementById('send-magic-link');
        this.authMessage = document.getElementById('auth-message');
        this.tasksList = document.getElementById('tasks-list');
        this.logoutBtn = document.getElementById('logout-btn');

        this.authManager = new AuthManager();
        this.taskManager = new TaskManager(this.authManager, this.tasksList);
    }

    async init() {
        // Check if user is already authenticated
        const session = await this.authManager.checkSession();
        if (session) {
            this.taskManager.showTasks(this.authSection, this.tasksSection);
        }

        // Listen for auth changes
        log.debug('event: ' || event);
        log.debug('session: ' || session);
        this.authManager.onAuthStateChange((event, session) => {
            log.in();
            log.debug('app');
            log.debug('event: ' || event);
            log.debug('session: ' || session);
            if (event === 'SIGNED_IN' && session) {
                this.taskManager.showTasks(this.authSection, this.tasksSection);
            } else if (event === 'SIGNED_OUT') {
                this.taskManager.hideTasksSection(this.authSection, this.tasksSection);
                this.tasksList.innerHTML = '';
            }
            log.out();
        });

        this.sendMagicLinkBtn.addEventListener('click', async () => {
            const email = this.emailInput.value.trim();
            if (!email) {
                this.authMessage.textContent = 'Введите email';
                return;
            }

            try {
                await this.authManager.sendMagicLink(email);
                this.authMessage.textContent = 'Magic link отправлен на ваш email. Проверьте почту.';
            } catch (error) {
                this.authMessage.textContent = 'Ошибка: ' + error.message;
            }
        });

        this.logoutBtn.addEventListener('click', async () => {
            try {
                await this.authManager.logout();
                this.taskManager.hideTasksSection(this.authSection, this.tasksSection);
                this.tasksList.innerHTML = '';
            } catch (error) {
                log.error('Ошибка при выходе:', error);
            }
        });
    }
}
