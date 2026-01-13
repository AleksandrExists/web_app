import { log } from './Logger.js';

export class TaskManager {
    constructor(authManager) {
        this.authManager = authManager;
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

    async loadTasksForDate(date) {
        log.in();
        const dateString = date.toISOString().split('T')[0];
        const { data: tasks, error } = await this.authManager.supabase
            .from('days')
            .select('*')
            .eq('date', dateString);
        if (error) throw error;
        log.out();
        return tasks;
    }

    renderTasksForDate(tasks, date) {
        log.in();
        this.tasksSection.innerHTML = '';
        if (tasks.length === 0) {
            this.tasksSection.innerHTML = '<p>У вас нет задач на этот день.</p>';
        } else {
            tasks.forEach(task => {
                const taskDiv = document.createElement('div');
                taskDiv.className = 'task';

                const input = document.createElement('input');
                input.type = 'number';
                input.step = '0.01';
                input.value = task.value || '';
                input.placeholder = 'Введите значение';
                input.className = 'task-input';
                input.dataset.taskId = task.task_id;

                input.addEventListener('change', async (e) => {
                    const value = parseFloat(e.target.value) || null;
                    try {
                        await this.updateTaskValue(date, task.task_id, value);
                        // Перезагрузить задачи для обновления расчетов
                        const updatedTasks = await this.loadTasksForDate(date);
                        this.renderTasksForDate(updatedTasks, date);
                    } catch (error) {
                        console.error('Ошибка сохранения:', error);
                        alert('Ошибка сохранения данных');
                    }
                });

                taskDiv.innerHTML = `
                    <h3>${task.name}</h3>
                    <p>Цель: ${task.target_value} к ${task.end_date}</p>
                    <p>Сейчас: ${task.fact_value}, темп: ${task.pace}%</p>
                `;
                taskDiv.appendChild(input);
                this.tasksSection.appendChild(taskDiv);
            });
        }
        log.out();
    }

    hideTasksSection() {
        log.in();
        this.tasksSection.classList.add('hidden');
        this.tasksSection.innerHTML = '';
        log.out();
    }

    async updateTaskValue(date, taskId, value) {
        log.in();
        const dateString = date.toISOString().split('T')[0];
        const { error } = await this.authManager.supabase
            .from('data')
            .update({ value: value || null })
            .eq('date', dateString)
            .eq('task_id', taskId);
        if (error) throw error;
        log.out();
    }

    async showTasksForDate(date) {
        log.in();
        this.tasksSection.classList.remove('hidden');
        await this.ensureUserProfile();
        try {
            const tasks = await this.loadTasksForDate(date);
            this.renderTasksForDate(tasks, date);
        } catch (error) {
            this.tasksSection.innerHTML = '<p>Ошибка загрузки задач: ' + error.message + '</p>';
        }
        log.out();
    }
}
