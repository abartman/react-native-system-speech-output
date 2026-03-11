# Publishing

Package name:
  @3senseai/react-native-system-speech-output

Recommended flow:

1. Review what will ship:
     npm pack --dry-run

2. First public release:
     npm login
     npm publish --access public

3. After the package exists on npm:
   - open the package page on npmjs.com
   - go to package settings
   - open Trusted Publisher
   - configure:
       organization or user: abartman
       repository: react-native-system-speech-output
       workflow filename: publish.yml

4. Future releases:
   - bump package.json version
   - commit and push
   - create and push a tag like v0.1.1
   - GitHub Actions publishes automatically

Notes:
- trusted publishing uses OIDC instead of long-lived npm write tokens
- the workflow file must live in .github/workflows/
- only one trusted publisher can be configured per package
