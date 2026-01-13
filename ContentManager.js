import { TaskManager } from './TaskManager.js';
import { log } from './Logger.js';

export class ContentManager {
    constructor(authManager) {
        this.authManager = authManager;
        this.daysSection = document.getElementById('days-section');
        this.tasksSection = document.getElementById('tasks-section');
        this.bottomSection = document.querySelector('.bottom-section');
        this.tasksList = document.getElementById('tasks-list');
        this.taskManager = new TaskManager(this.authManager, this.tasksList);
    }

    showContent() {
        log.in();
        // Показать дни недели
        this.showDays();
        // Показать задачи
        this.showTasks();
        // Показать нижнюю панель
        this.showBottomNav();
        log.out();
    }

    hideContent() {
        log.in();
        this.hideDays();
        this.hideTasks();
        this.hideBottomNav();
        log.out();
    }

    showDays() {
        log.in();
        this.daysSection.classList.remove('hidden');
        // Добавить кнопки дней, если не добавлены
        if (this.daysSection.children.length === 0) {
            const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
            days.forEach(day => {
                const button = document.createElement('button');
                button.className = 'day-button';
                button.textContent = day;
                this.daysSection.appendChild(button);
            });
        }
        log.out();
    }

    hideDays() {
        log.in();
        this.daysSection.classList.add('hidden');
        log.out();
    }

    async showTasks() {
        log.in();
        this.tasksSection.classList.remove('hidden');
        await this.taskManager.ensureUserProfile();
        try {
            const tasks = await this.taskManager.loadTasks();
            this.taskManager.renderTasks(tasks);
        } catch (error) {
            this.tasksList.innerHTML = '<p>Ошибка загрузки задач: ' + error.message + '</p>';
        }
        log.out();
    }

    hideTasks() {
        log.in();
        this.tasksSection.classList.add('hidden');
        this.tasksList.innerHTML = '';
        log.out();
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
