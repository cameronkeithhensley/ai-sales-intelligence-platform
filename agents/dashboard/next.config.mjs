/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Standalone output keeps the production image small — `next build` emits
  // a minimal server directory that `node src/index.js` can serve from.
  output: "standalone",
};

export default nextConfig;
