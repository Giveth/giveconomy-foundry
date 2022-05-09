import { isArray } from 'lodash';

// Wrap anything into an array:
export function arrayWrap(x: any) {
  if (!isArray(x)) {
    return [x];
  }
  return x;
}
