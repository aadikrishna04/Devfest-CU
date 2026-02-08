import { AlertTriangle } from 'lucide-react';

export function SafetyDisclaimer() {
  return (
    <section className="py-12 px-6 bg-white dark:bg-gray-950 border-t border-gray-200 dark:border-gray-800">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-start gap-3 text-sm text-gray-600 dark:text-gray-400">
          <AlertTriangle className="w-4 h-4 text-[#D4594D] mt-0.5 flex-shrink-0" />
          <p className="leading-relaxed">
            <strong className="text-gray-900 dark:text-white">Decision support only</strong> — not a substitute for professional medical help. Always call emergency services when appropriate; follow local first-aid guidelines and training.
          </p>
        </div>
      </div>
    </section>
  );
}