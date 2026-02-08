import { Hero } from './components/Hero';
import { KeyFeatures } from './components/KeyFeatures';
import { Architecture } from './components/Architecture';
import { UserWalkthrough } from './components/UserWalkthrough';
import { SafetyDisclaimer } from './components/SafetyDisclaimer';
import { DarkModeToggle } from './components/DarkModeToggle';
import { useState, useEffect } from 'react';

export default function App() {
  const [darkMode, setDarkMode] = useState(false);

  useEffect(() => {
    if (darkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [darkMode]);

  return (
    <div className="min-h-screen bg-white dark:bg-gray-950 transition-colors">
      <DarkModeToggle darkMode={darkMode} setDarkMode={setDarkMode} />
      <Hero />
      <KeyFeatures />
      <Architecture />
      <UserWalkthrough />
      <SafetyDisclaimer />
    </div>
  );
}