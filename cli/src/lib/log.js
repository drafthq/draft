'use strict';

// Minimal, dependency-free logging. Plain ASCII so it renders everywhere.
function info(msg) {
  console.log(msg);
}

function step(msg) {
  console.log('\n' + msg);
}

function plan(msg) {
  console.log('  - ' + msg);
}

function note(msg) {
  console.log('  > ' + msg);
}

function success(msg) {
  console.log('OK  ' + msg);
}

function warn(msg) {
  console.warn('!   ' + msg);
}

function error(msg) {
  console.error('x   ' + msg);
}

module.exports = { info, step, plan, note, success, warn, error };
