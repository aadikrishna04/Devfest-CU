import { Smartphone, Glasses, Play, Ear, MessageSquare, Activity, CheckCircle, StopCircle } from 'lucide-react';

export function UserWalkthrough() {
  const steps = [
    {
      number: 1,
      icon: Glasses,
      title: "Connect glasses",
      description: "Open the app, tap 'Connect Glasses,' complete Meta's pairing/registration (and any OAuth in-browser).",
      status: "Setup"
    },
    {
      number: 2,
      icon: Play,
      title: "Start session",
      description: "When the glasses are connected, tap 'Start Session'; grant mic, speech, and camera permissions if prompted.",
      status: "Setup"
    },
    {
      number: 3,
      icon: Activity,
      title: "See the feed",
      description: "Video from the glasses and an audio visualizer show that the session is live; status shows 'Say Medkit to start' (or 'Listening' when active).",
      status: "Ready"
    },
    {
      number: 4,
      icon: Ear,
      title: "Activate",
      description: "Say 'Medkit' (or a close phrase the app accepts); status switches to 'Listening' and audio is sent to the coach.",
      status: "Active"
    },
    {
      number: 5,
      icon: MessageSquare,
      title: "Describe the situation",
      description: "e.g. 'My friend fell and isn't breathing.' The coach responds by voice and may set a scenario (e.g. CPR); the phone shows checklists, metronome, and timers.",
      status: "Active"
    },
    {
      number: 6,
      icon: Activity,
      title: "Follow guidance",
      description: "User follows voice steps and glances at the phone for rhythm, timers, or checklist; if the coach gets a scene update, it may say something like 'Your hands look good — keep that pace.'",
      status: "Active"
    },
    {
      number: 7,
      icon: CheckCircle,
      title: "Check-ins",
      description: "If the user is silent for a while, the coach may ask a short check-in; user can answer or keep going.",
      status: "Active"
    },
    {
      number: 8,
      icon: StopCircle,
      title: "End session",
      description: "User taps stop and/or disconnects the glasses when done.",
      status: "Complete"
    }
  ];

  const getStatusColor = (status: string) => {
    switch (status) {
      case "Setup":
        return "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300";
      case "Ready":
        return "bg-[#D4594D]/10 dark:bg-[#D4594D]/20 text-[#D4594D]";
      case "Active":
        return "bg-[#D4594D] text-white";
      case "Complete":
        return "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300";
      default:
        return "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300";
    }
  };

  return (
    <section className="py-24 px-6 bg-gray-50 dark:bg-gray-900">
      <div className="max-w-5xl mx-auto">
        <h2 className="text-4xl mb-6 text-gray-900 dark:text-white">User walkthrough</h2>
        <p className="text-lg text-gray-600 dark:text-gray-400 mb-16">
          First-time user journey from connecting glasses to completing a session
        </p>
        
        <div className="relative">
          {/* Timeline line - starts above first step */}
          <div className="absolute left-8 -top-10 bottom-0 w-0.5 bg-gradient-to-b from-[#D4594D] via-[#EB9E94] to-gray-200 dark:to-gray-700" />
          
          <div className="space-y-8">
            {steps.map((step) => (
              <div key={step.number} className="relative pl-20">
                {/* Step number circle - opaque so timeline line doesn't show through */}
                <div className="absolute left-0 w-16 h-16 rounded-full bg-gray-50 dark:bg-gray-900 flex items-center justify-center border-2 border-[#D4594D] z-10">
                  <step.icon className="w-7 h-7 text-[#D4594D]" />
                </div>
                
                <div className="bg-white dark:bg-gray-800 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
                  <div className="flex items-center gap-3 mb-3">
                    <span className={`text-xs px-3 py-1 rounded-full ${getStatusColor(step.status)}`}>
                      {step.status}
                    </span>
                    <h3 className="text-base text-gray-900 dark:text-white">{step.title}</h3>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}