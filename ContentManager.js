import { TaskManager } from './TaskManager.js';
import { DaysManager } from './DaysManager.js';
import { BottomNavManager } from './BottomNavManager.js';
import { log } from './Logger.js';

export class ContentManager {
    constructor(authManager, onReportsClick, onAddClick, onLogoutClick) {
        this.tasksList = document.getElementById('tasks-list');

        this.taskManager = new TaskManager(authManager, this.tasksList);
        this.daysManager = new DaysManager();
        this.bottomNavManager = new BottomNavManager(onReportsClick, onAddClick, onLogoutClick);
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
        this.daysManager.showDays();
    }

    hideDays() {
        this.daysManager.hideDays();
    }

    async showTasks() {
        log.in();
        this.taskManager.showTasks();
        log.out();
    }

    hideTasks() {
        this.taskManager.hideTasksSection();
    }

    showBottomNav() {
        this.bottomNavManager.showBottomNav();
    }

    hideBottomNav() {
        this.bottomNavManager.hideBottomNav();
    }
}
