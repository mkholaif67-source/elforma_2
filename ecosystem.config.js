// PM2 Ecosystem Config — ElForma
// شغّل بـ: pm2 start ecosystem.config.js
// عالج بـ: pm2 reload ecosystem.config.js --update-env
module.exports = {
  apps: [
    {
      name: 'elforma',
      script: 'server.js',
      node_args: '--experimental-sqlite',

      // Cluster mode: يستخدم كل الـ CPU cores للـ HTTP requests
      // كل instance عنده Worker Thread pool منفصل للـ engine
      instances: 'max',   // أو رقم محدد: 2 أو 4
      exec_mode: 'cluster',

      // إعادة تشغيل تلقائي
      watch: false,
      autorestart: true,
      max_restarts: 10,
      restart_delay: 2000,

      // حد الذاكرة قبل إعادة التشغيل (512MB لكل instance)
      max_memory_restart: '512M',

      // Zero-downtime reload: instance جديد يشتغل قبل ما القديم يقف
      listen_timeout: 10000,
      kill_timeout: 5000,

      env: {
        NODE_ENV: 'production',
        EF_ENV: 'production',
        PORT: 8000,
        // عدد الـ worker threads للـ engine (واحد لكل instance كافي في cluster)
        ENGINE_POOL_SIZE: 1,
        ENGINE_TASK_TIMEOUT_MS: 15000
      },

      env_development: {
        NODE_ENV: 'development',
        EF_ENV: 'development',
        PORT: 8000,
        ENGINE_POOL_SIZE: 2
      }
    }
  ]
};
