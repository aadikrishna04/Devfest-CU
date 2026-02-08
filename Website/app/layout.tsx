import type { Metadata } from "next";
import "@/app/globals.css";
import { Providers } from "@/components/providers";

export const metadata: Metadata = {
  title: "Medkit — First-aid guidance in your ear, hands-free",
  description:
    "An AI first-aid coach for Meta smart glasses. Voice-guided, hands-free emergency support with real-time visual aids.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-screen bg-white dark:bg-gray-950 transition-colors">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
