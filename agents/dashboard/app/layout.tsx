import type { ReactNode } from "react";

export const metadata = {
  title: "AI Sales Intelligence Platform",
  description: "Portfolio skeleton for the tenant-facing dashboard.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          fontFamily:
            'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
          margin: 0,
          padding: 0,
          backgroundColor: "#0b0c10",
          color: "#e8e8ea",
          minHeight: "100vh",
        }}
      >
        {children}
      </body>
    </html>
  );
}
