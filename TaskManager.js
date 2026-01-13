import { log } from './Logger.js';

export class TaskManager {
    constructor(authManager, tasksListElement) {
        this.authManager = authManager;
        this.tasksListElement = tasksListElement;
        this.tasksSection = document.getElementById('tasks-section');
    }

    async ensureUserProfile() {
        log.in();
        const { data: { user } } = await this.authManager.supabase.auth.getUser();
        log.debug({ user });
        if (user) {
            const { data: existingUser } = await this.authManager.supabase.from('users').select('id').single();
            log.debug(existingUser);
            if (!existingUser) {
                await this.authManager.supabase.from('users').insert({
                    id: user.id,
                    email: user.email
                });
            }
        }
        log.out();
    }

    async loadTasks() {
        log.in();
        const { data: tasks, error } = await this.authManager.supabase.from('tasks').select('*');
        if (error) throw error;
        log.out();
        return tasks;
    }

    renderTasks(tasks) {
        log.in();
        this.tasksListElement.innerHTML = '';
        if (tasks.length === 0) {
            this.tasksListElement.innerHTML = '<p>У вас нет задач.</p>';
        } else {
            tasks.forEach(task => {
                const taskDiv = document.createElement('div');
                taskDiv.className = 'task';
                taskDiv.innerHTML = `
                    <h3>${task.name}</h3>
                    <p>Тип: ${task.type_id}</p>
                    <p>Начальное значение: ${task.start_value}</p>
                    <p>Целевое значение: ${task.target_value}</p>
                    <p>Дата начала: ${task.begin_date}</p>
                    <p>Дата окончания: ${task.end_date}</p>
                `;
                this.tasksListElement.appendChild(taskDiv);
            });
        }
        log.out();
    }

    hideTasksSection() {
        log.in();
        this.tasksSection.classList.add('hidden');
        this.tasksListElement.innerHTML = '';
        log.out();
    }

    async showTasks() {
        log.in();
        this.tasksSection.classList.remove('hidden');
        await this.ensureUserProfile();
        try {
            const tasks = await this.loadTasks();
            this.renderTasks(tasks);
        } catch (error) {
            this.tasksListElement.innerHTML = '<p>Ошибка загрузки задач: ' + error.message + '</p>';
        }
        log.out();
    }
}
