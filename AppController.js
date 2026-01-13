import { AuthManager } from './AuthManager.js';
import { ContentManager } from './ContentManager.js';
import { log } from './Logger.js';

export class App {
    constructor() {
        this.authSection = document.getElementById('auth-section');
        this.contentSection = document.getElementById('content-section');
        this.emailInput = document.getElementById('email');
        this.sendMagicLinkBtn = document.getElementById('send-magic-link');
        this.authMessage = document.getElementById('auth-message');

        this.authManager = new AuthManager();
        this.contentManager = new ContentManager(
            this.authManager,
            this.onReportsClick.bind(this),
            this.onAddClick.bind(this),
            this.onLogoutClick.bind(this)
        );
    }

    async init() {
        // Check if user is already authenticated
        const session = await this.authManager.checkSession();
        if (session) {
            this.showContentSection();
            this.contentManager.showContent();
        }

        // Listen for auth changes
        this.authManager.onAuthStateChange((event, session) => {
            log.in();
            log.debug('app');
            log.debug('event: ' || event);
            log.debug('session: ' || session);
            if (event === 'SIGNED_IN' && session) {
                this.showContentSection();
                this.contentManager.showContent();
            } else if (event === 'SIGNED_OUT') {
                this.showAuthSection();
                this.contentManager.hideContent();
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
    }

    showAuthSection() {
        this.contentSection.classList.add('hidden');
        this.authSection.classList.remove('hidden');
    }

    showContentSection() {
        this.contentSection.classList.remove('hidden');
        this.authSection.classList.add('hidden');
    }

    onReportsClick() {
        log.debug('Reports functionality not implemented yet');
        // TODO: Implement reports functionality
    }

    onAddClick() {
        log.debug('Add habit functionality not implemented yet');
        // TODO: Implement add habit functionality
    }

    async onLogoutClick() {
        try {
            await this.authManager.logout();
            this.showAuthSection();
            this.contentManager.hideContent();
        } catch (error) {
            log.error('Ошибка при выходе:', error);
        }
    }
}
