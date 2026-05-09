module.exports = {
  content: ['./index.html', './src/**/*.{svelte,ts}'],
  theme: {
    extend: {
      colors: {
        ink: {
          900: '#1c241d',
          700: '#465147',
          500: '#6c766d',
          200: '#dbe2dc',
          100: '#eef2ee'
        },
        moss: {
          50: '#f4faf4',
          100: '#e5f2e6',
          300: '#b8d7be',
          500: '#7cab84',
          600: '#63946d'
        },
        sand: '#f7f5ef',
        mist: '#fbfbf8'
      },
      boxShadow: {
        soft: '0 18px 50px rgba(28, 36, 29, 0.08)',
        card: '0 10px 30px rgba(28, 36, 29, 0.06)'
      },
      borderRadius: {
        xl2: '1.5rem'
      }
    }
  },
  plugins: []
};
