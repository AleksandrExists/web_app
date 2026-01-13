import { TaskManager } from './TaskManager.js';
import { DaysManager } from './DaysManager.js';
import { BottomNavManager } from './BottomNavManager.js';
import { log } from './Logger.js';

export class ContentManager {
    constructor(authManager, onReportsClick, onAddClick, onLogoutClick) {
        this.taskManager = new TaskManager(authManager);
        this.daysManager = new DaysManager((date) => this.selectDate(date));
        this.bottomNavManager = new BottomNavManager(onReportsClick, onAddClick, onLogoutClick);
        this.selectedDate = new Date();
    }

    showContent() {
        log.in();
        // Показать дни недели
        this.showDays();
        // Выбрать текущий день
        this.daysManager.selectDay(this.selectedDate);
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

    selectDate(date) {
        log.in();
        this.selectedDate = date;
        this.taskManager.showTasksForDate(date);
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
