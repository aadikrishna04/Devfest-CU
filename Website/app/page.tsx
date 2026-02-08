import { Hero } from "@/components/Hero";
import { KeyFeatures } from "@/components/KeyFeatures";
import { Architecture } from "@/components/Architecture";
import { UserWalkthrough } from "@/components/UserWalkthrough";
import { SafetyDisclaimer } from "@/components/SafetyDisclaimer";

export default function Home() {
  return (
    <>
      <Hero />
      <KeyFeatures />
      <Architecture />
      <UserWalkthrough />
      <SafetyDisclaimer />
    </>
  );
}
