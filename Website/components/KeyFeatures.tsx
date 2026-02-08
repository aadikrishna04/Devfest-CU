import { Mic2, Zap, Brain, ListChecks, Timer, Eye } from 'lucide-react';

export function KeyFeatures() {
  const features = [
    {
      icon: Mic2,
      title: "Voice-first coach",
      description: "Short, direct replies. One step at a time. Designed for hands-busy use."
    },
    {
      icon: Zap,
      title: "Wake word & hands-free",
      description: "Say 'Medkit' to start. Stays active in critical scenarios."
    },
    {
      icon: Brain,
      title: "Scenario-aware",
      description: "AI infers situation type and severity from conversation."
    },
    {
      icon: ListChecks,
      title: "On-screen checklists",
      description: "Step-by-step cards and checklists on your phone so you know exactly what to do next."
    },
    {
      icon: Timer,
      title: "Live tools",
      description: "Metronome for CPR, countdown timers, on-screen checklists."
    },
    {
      icon: Eye,
      title: "Scene understanding",
      description: "Camera analyzes hand placement and position to refine guidance."
    }
  ];

  return (
    <section className="py-24 px-6 bg-gray-50 dark:bg-gray-900">
      <div className="max-w-6xl mx-auto">
        <h2 className="text-4xl mb-16 text-gray-900 dark:text-white">Features</h2>
        
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => (
            <div 
              key={index}
              className="bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-200 dark:border-gray-700"
            >
              <div className="w-12 h-12 rounded-xl bg-[#D4594D]/10 dark:bg-[#D4594D]/20 flex items-center justify-center mb-4">
                <feature.icon className="w-6 h-6 text-[#D4594D]" />
              </div>
              <h3 className="text-lg mb-2 text-gray-900 dark:text-white">{feature.title}</h3>
              <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}