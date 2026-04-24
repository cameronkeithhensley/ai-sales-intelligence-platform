import NextAuth, { type NextAuthOptions } from "next-auth";
import CognitoProvider from "next-auth/providers/cognito";

// Cognito configuration. COGNITO_ISSUER looks like
//   https://cognito-idp.<region>.amazonaws.com/<user_pool_id>
// COGNITO_CLIENT_SECRET is optional in dev (public SPA-style clients
// do not carry one) but required for the confidential web-app client
// pattern that the Sprint 1 Cognito module provisions.
const options: NextAuthOptions = {
  providers: [
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID ?? "",
      clientSecret: process.env.COGNITO_CLIENT_SECRET ?? "",
      issuer: process.env.COGNITO_ISSUER ?? "",
    }),
  ],
  session: {
    strategy: "jwt",
  },
  callbacks: {
    async jwt({ token, account }) {
      if (account?.id_token) {
        token.idToken = account.id_token;
      }
      return token;
    },
    async session({ session, token }) {
      // Expose the Cognito sub so app code can resolve the caller's
      // tenant from the tenants table. The resolver implementation
      // is proprietary and does not ship in this public repository.
      session.userId = (token.sub as string | undefined) ?? null;
      return session;
    },
  },
};

const handler = NextAuth(options);

export { handler as GET, handler as POST };
