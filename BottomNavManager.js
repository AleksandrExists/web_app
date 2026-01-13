import { log } from './Logger.js';

export class BottomNavManager {
    constructor(onReportsClick, onAddClick, onLogoutClick) {
        this.bottomSection = document.querySelector('.bottom-section');
        this.reportsBtn = document.getElementById('reports-btn');
        this.addHabitBtn = document.getElementById('add-habit-btn');
        this.logoutBtn = document.getElementById('logout-btn');

        // Привязать обработчики
        this.reportsBtn.addEventListener('click', () => {
            log.debug('Reports button clicked');
            if (onReportsClick) onReportsClick();
        });

        this.addHabitBtn.addEventListener('click', () => {
            log.debug('Add habit button clicked');
            if (onAddClick) onAddClick();
        });

        this.logoutBtn.addEventListener('click', async () => {
            log.debug('Logout button clicked');
            if (onLogoutClick) await onLogoutClick();
        });
    }

    showBottomNav() {
        log.in();
        this.bottomSection.classList.remove('hidden');
        log.out();
    }

    hideBottomNav() {
        log.in();
        this.bottomSection.classList.add('hidden');
        log.out();
    }
}
