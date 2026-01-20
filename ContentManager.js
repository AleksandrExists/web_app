import { ItemManager } from './ItemManager.js';
import { DaysManager } from './DaysManager.js';
import { DayInfoManager } from './DayInfoManager.js';
import { BottomNavManager } from './BottomNavManager.js';
import { log } from './Logger.js';

export class ContentManager {
    constructor(authManager, onReportsClick, onAddClick, onLogoutClick) {
        this.itemManager = new ItemManager(authManager);
        this.daysManager = new DaysManager((date) => this.selectDate(date));
        this.dayInfoManager = new DayInfoManager(authManager);
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
        this.hideItems();
        this.dayInfoManager.hideDayInfo();
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
        this.itemManager.showItemsForDate(date);
        this.dayInfoManager.showDayInfo(date);
        log.out();
    }

    hideItems() {
        this.itemManager.hideItemsSection();
    }

    showBottomNav() {
        this.bottomNavManager.showBottomNav();
    }

    hideBottomNav() {
        this.bottomNavManager.hideBottomNav();
    }
}
