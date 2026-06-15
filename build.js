const { execSync } = require('child_process');
const { statSync } = require('fs');
const path = require('path');

const dir = __dirname;
const targets = [
  { os: 'darwin', arch: 'amd64', out: 'mdmap-darwin' },
  { os: 'linux', arch: 'amd64', out: 'mdmap-linux' },
  { os: 'windows', arch: 'amd64', out: 'mdmap-windows.exe' },
];

try {
  execSync('go version', { stdio: 'pipe' });
} catch {
  console.error('Error: go is not installed or not in PATH.');
  process.exit(1);
}

for (const t of targets) {
  console.log(`Building ${t.out} (${t.os} ${t.arch})...`);
  execSync(`go build -o "${path.join(dir, t.out)}" .`, {
    cwd: dir,
    stdio: 'inherit',
    env: { ...process.env, GOOS: t.os, GOARCH: t.arch },
  });
}

console.log('Done:');
for (const t of targets) {
  const size = statSync(path.join(dir, t.out)).size;
  console.log(`  ${t.out}  ${(size / 1024 / 1024).toFixed(1)} MB`);
}
