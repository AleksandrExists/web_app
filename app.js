import { App } from './AppController.js';

(async () => {
    const app = new App();
    await app.init();
})();
