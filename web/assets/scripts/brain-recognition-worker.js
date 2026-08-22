'use strict';

let templates = null;

function isInk(pixels, index) {
  return pixels[index + 3] > 20 && pixels[index] < 220 && pixels[index + 1] < 220 && pixels[index + 2] < 220;
}

function alphaBounds(pixels, width, height) {
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const index = (y * width + x) * 4;
      if (!isInk(pixels, index)) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return maxX >= minX ? { minX, minY, maxX, maxY } : null;
}

function dilate(bits, width, height, radius = 2) {
  const output = new Uint8Array(bits.length);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (!bits[y * width + x]) continue;
      const minY = Math.max(0, y - radius);
      const maxY = Math.min(height - 1, y + radius);
      const minX = Math.max(0, x - radius);
      const maxX = Math.min(width - 1, x + radius);
      for (let py = minY; py <= maxY; py += 1) {
        output.fill(1, py * width + minX, py * width + maxX + 1);
      }
    }
  }
  return output;
}


function analyzeHoles(bits, width, height) {
  const visited = new Uint8Array(bits.length);
  const queue = [];
  const pushBackground = (x, y) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const index = y * width + x;
    if (bits[index] || visited[index]) return;
    visited[index] = 1;
    queue.push(index);
  };
  for (let x = 0; x < width; x += 1) { pushBackground(x, 0); pushBackground(x, height - 1); }
  for (let y = 0; y < height; y += 1) { pushBackground(0, y); pushBackground(width - 1, y); }
  for (let cursor = 0; cursor < queue.length; cursor += 1) {
    const index = queue[cursor];
    const x = index % width;
    const y = Math.floor(index / width);
    pushBackground(x + 1, y); pushBackground(x - 1, y); pushBackground(x, y + 1); pushBackground(x, y - 1);
  }
  const holes = [];
  for (let index = 0; index < bits.length; index += 1) {
    if (bits[index] || visited[index]) continue;
    const component = [index];
    visited[index] = 1;
    let count = 0;
    let sumX = 0;
    let sumY = 0;
    for (let cursor = 0; cursor < component.length; cursor += 1) {
      const current = component[cursor];
      const x = current % width;
      const y = Math.floor(current / width);
      count += 1; sumX += x; sumY += y;
      for (const next of [current - 1, current + 1, current - width, current + width]) {
        if (next < 0 || next >= bits.length || visited[next] || bits[next]) continue;
        const nx = next % width;
        const ny = Math.floor(next / width);
        if (Math.abs(nx - x) + Math.abs(ny - y) !== 1) continue;
        visited[next] = 1;
        component.push(next);
      }
    }
    if (count >= 4) holes.push({ x: sumX / count / width, y: sumY / count / height, area: count / bits.length });
  }
  holes.sort((a, b) => a.y - b.y);
  return holes.slice(0, 3);
}

function normalizedBitmap(pixels, sourceWidth, sourceHeight, crop) {
  const width = 28;
  const height = 36;
  const bits = new Uint8Array(width * height);
  const cropWidth = Math.max(1, crop.maxX - crop.minX + 1);
  const cropHeight = Math.max(1, crop.maxY - crop.minY + 1);
  const scale = Math.min((width - 6) / cropWidth, (height - 6) / cropHeight);
  const drawWidth = cropWidth * scale;
  const drawHeight = cropHeight * scale;
  const offsetX = (width - drawWidth) / 2;
  const offsetY = (height - drawHeight) / 2;

  for (let y = crop.minY; y <= crop.maxY; y += 1) {
    for (let x = crop.minX; x <= crop.maxX; x += 1) {
      const index = (y * sourceWidth + x) * 4;
      if (!isInk(pixels, index)) continue;
      const tx = Math.max(0, Math.min(width - 1, Math.round(offsetX + (x - crop.minX) * scale)));
      const ty = Math.max(0, Math.min(height - 1, Math.round(offsetY + (y - crop.minY) * scale)));
      bits[ty * width + tx] = 1;
    }
  }

  const softened = dilate(bits, width, height, 1);
  let ink = 0;
  for (let index = 0; index < softened.length; index += 1) ink += softened[index];
  return {
    bits: softened,
    dilated: dilate(softened, width, height, 2),
    width,
    height,
    ink,
    aspect: cropWidth / cropHeight,
    holes: analyzeHoles(softened, width, height),
  };
}

function digitSegments(pixels, width, height, bounds) {
  const active = [];
  for (let x = bounds.minX; x <= bounds.maxX; x += 1) {
    let count = 0;
    for (let y = bounds.minY; y <= bounds.maxY; y += 1) {
      if (isInk(pixels, (y * width + x) * 4)) count += 1;
    }
    active.push(count);
  }

  const groups = [];
  let start = null;
  let gapStart = null;
  const minGap = Math.max(3, Math.round(width / 100));
  for (let index = 0; index < active.length; index += 1) {
    if (active[index] > 0) {
      if (start === null) start = index;
      gapStart = null;
    } else if (start !== null) {
      if (gapStart === null) gapStart = index;
      if (index - gapStart + 1 >= minGap) {
        groups.push([start + bounds.minX, gapStart - 1 + bounds.minX]);
        start = null;
        gapStart = null;
      }
    }
  }
  if (start !== null) groups.push([start + bounds.minX, bounds.maxX]);

  if (groups.length === 1) {
    const [minX, maxX] = groups[0];
    const groupWidth = maxX - minX + 1;
    const groupHeight = bounds.maxY - bounds.minY + 1;
    if (groupWidth > groupHeight * 1.12) {
      const valleyThreshold = Math.max(1, Math.round(groupHeight * 0.04));
      const candidates = [];
      for (let x = minX + Math.round(groupWidth * 0.18); x <= maxX - Math.round(groupWidth * 0.18); x += 1) {
        let count = 0;
        for (let y = bounds.minY; y <= bounds.maxY; y += 1) {
          if (isInk(pixels, (y * width + x) * 4)) count += 1;
        }
        if (count <= valleyThreshold) candidates.push({ x, count });
      }
      if (candidates.length) {
        candidates.sort((a, b) => a.count - b.count || Math.abs(a.x - (minX + maxX) / 2) - Math.abs(b.x - (minX + maxX) / 2));
        const split = candidates[0].x;
        return [[minX, split - 1], [split + 1, maxX]];
      }
    }
  }

  return groups.slice(0, 4);
}

function bitmapSimilarity(sample, template) {
  let missedSample = 0;
  let missedTemplate = 0;
  for (let index = 0; index < sample.bits.length; index += 1) {
    if (sample.bits[index] && !template.dilated[index]) missedSample += 1;
    if (template.bits[index] && !sample.dilated[index]) missedTemplate += 1;
  }
  const shape = 1 - (missedSample + missedTemplate) / Math.max(1, sample.ink + template.ink);
  const density = 1 - Math.min(1, Math.abs(sample.ink - template.ink) / Math.max(sample.ink, template.ink, 1));
  const aspect = 1 - Math.min(1, Math.abs(sample.aspect - template.aspect) / 1.5);
  const sampleHoles = sample.holes || [];
  const templateHoles = template.holes || [];
  let topology = Math.max(0, 1 - Math.abs(sampleHoles.length - templateHoles.length) * 0.72);
  if (sampleHoles.length === templateHoles.length && sampleHoles.length) {
    let position = 0;
    for (let index = 0; index < sampleHoles.length; index += 1) {
      const dx = Math.abs(sampleHoles[index].x - templateHoles[index].x);
      const dy = Math.abs(sampleHoles[index].y - templateHoles[index].y);
      const da = Math.abs(sampleHoles[index].area - templateHoles[index].area) * 3;
      position += Math.max(0, 1 - dx - dy * 1.4 - da);
    }
    topology = position / sampleHoles.length;
  }
  return shape * 0.56 + density * 0.10 + aspect * 0.09 + topology * 0.25;
}

const EMBEDDED_TEMPLATES = [{"digit":"0","bits":"AAAAAAAAAAAAAADAPwAA/x8A+P8DwP9/AP7/D/D//wH//x/4//+D//E/+B/+w//gP/wP/sP/4D/8D/7Df+A//Af+w3/wP/wH/8N/8D/8B//Df/gf/I//wf//H/j//4D//w/w/38A/v8DwP8fAPj/AAD8AwAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"0","bits":"AAAAAAAAAAAAAADgfwCA/x8A/P8D4P9/AP//D/D//4D//x/4n//B//A//A//w//wP/wH/sN/4D/8B/7Df+A//Af+w3/gP/wH/sP/8D/8D//D//A/+J//gf//H/D//wD//w/g/38A/P8DgP8fAOB/AAAAAAAAAAAAAAAAAAAA","aspect":0.81159},{"digit":"0","bits":"AAAAAAAAAAAAAADAPwCA/w8A/P8B4P8/AP//B/j//4D//w/8///B//gf/If/wX/wP/wH/8N/8D/8B//Df+A//Af+w//gP/wP/sP/4D/8D/6D/+E/+B//g///P/D//wH//x/g//8A/P8HgP8/APD/AQD8AwAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"0","bits":"AAAAAAAAAAAAAADAPwAA/x8A/P8D4P9/AP7/D/A//4H/4R/4H/6B/+E//A/+w//gP/wP/8P/8D/8D//D//A//Af/w3/wP/wH/8N/+B/8h//Bf/gf/If/gX/4D/jP/wD//wfw/z8A/P8BgP8PAMA/AAAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"0","bits":"AAAAAAAAAAAAAADgfwCA/x8A/P8D4P9/AP//D/if/4H/8B/4D//B//A//A//w//wP/wP/8P/8D/8D//D//A//A//w//wP/wP/8P/8D/8D//D//A/+A//gf/wH/if/wH//w/g/38A/P8DgP8fAOB/AAAAAAAAAAAAAAAAAAAA","aspect":0.81159},{"digit":"0","bits":"AAAAAAAAAAAAAADAPwCA/w8A/P8D4P9/AP//B/jP/4B/+B/4h//Bf/gf/Af/w3/wP/wP/8P/8D/8D//D//A//A/+w//gP/wP/oP/4T/4H/6D/+E/+B/+A//hH/A//wH+/w/A//8A+P8DAP8fAMB/AAAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"0","bits":"AAAAAAAAAAD8BwDw/wGA/z8A/P8HwP//AP7/D+D//wH/8x/wH/4B/+Ef8A/+gf/gH/gP/oH/4B/4B/6Bf+Af+Af+gX/gH/gH/4F/8B/4B/+Bf/AP+If/gP/4D/jffwD//wfw/38A/v8D4P8fAPz/AAD/BwDAHwAAAAAAAAAA","aspect":0.68182},{"digit":"0","bits":"AAAAAAAAAAD/BwD4/wDg/z8A/v8D8P9/AP//B/j//4D/+A/4j//Af/Af/Af/wX/wH/wH/8F/8B/8A/7BP+Af/AP+wT/wH/wH/8F/8B/8B//Bf/Af/Af/gf/4D/iP/4D//w/w/38A//8H4P8/APz/AYD/DwDwPwAAAAAAAAAA","aspect":0.69231},{"digit":"0","bits":"AAAAAAAAAAD8AQD4fwDA/w8A/v8B8P8/gP//B/j/f4D//gf8h//Af/gP/If/wD/wD/wD/8F/8B/8B//Bf/Af/Af+wX/gH/gH/oF/4B/4D/6B/+Af+A/+Af/xH/Af/wH//w/g//8A/v8PwP9/APj/AwD/HwDgfwAAAAAAAAAA","aspect":0.69697},{"digit":"0","bits":"AAAAAAAAAAD8BwDw/wGA/z8A/P8H4P//AP7/H/D//wH/8x/4H/6D/+A/+A/8g3/AP/wH/MN/wD/8B/zDf8A//AP8wz/gP/wD/sM/4D/8A/7Df/Af/Af/gX/4H/jP/4D//w/w/38A//8H4P8/APz/AQD/BwDAHwAAAAAAAAAA","aspect":0.72857},{"digit":"0","bits":"AAAAAAAAAAD+BwD4/wHA/z8A/v8H8P9/AP//D/j//4D/+B/4D//Bf+Af/Af+w3/gP/wD/sM/wD/8A/zDP8A//AP8wz/AP/wD/MM/4D/8B/7Df+A//Af+gf/wH/iP/4H//w/w//8A//8H4P9/APz/A4D/HwDgfwAAAAAAAAAA","aspect":0.72464},{"digit":"0","bits":"AAAAAAAAAAD8AQD4fwDA/x8A/v8D8P9/AP//B/j//4D//A/8h//Bf/Af/AP/wT/gH/wD/sM/4D/8A/7DP8A//AP8w3/AP/wH/MN/wD/4B/yD/8A/+A/+g//hP/Af/wH//x/g//8B/v8PwP9/APj/AwD/HwDAfwAAAAAAAAAA","aspect":0.72857},{"digit":"0","bits":"AAAAAAAAAAD8AwDw/wCA/z8A/P8H4P9/AP7/D/D//wD//x/4H/+B//Ef+A//gf/gH/gP/sF/4B/8B//Bf/Af/Af/wX/wH/wH/8F/8B/8h//Af/gP/If/wH/8D/j/f4D//wf4/38A//8D4P8fAPz/AID/BwDgHwAAAAAAAAAA","aspect":0.68571},{"digit":"0","bits":"AAAAAAAAAAD/AwD8/wDg/x8A/v8D8P9/gP//B/j//4D//Q/8j//Af/gP/Af/wX/wH/wH/8F/8B/8B//Bf/Af/Af/wX/wH/wH/8F/8B/8B//Bf/Af/If/gP/4D/jf/4D//w/w/38A//8H4P8/APz/AYD/DwDwfwAAAAAAAAAA","aspect":0.69118},{"digit":"0","bits":"AAAAAAAAAAD+AQD4fwDg/w8A//8B8P8/gP//A/j/f4D//wf8z//Af/gP/If/wH/4D/wH/8F/8B/8B//Bf/Af/Af/wX/wH/wH/oH/4B/4D/6B//Af+A//gf/xH/C//wH//w/g//8A/v8PwP9/APj/AwD/HwDgfwAAAAAAAAAA","aspect":0.69565},{"digit":"1","bits":"AAAAAAAAAMD/BwD8/wPA/z8A/v8D4P8/AP7/AeD/HwD+/wEA+B8AgP8BAPgfAID/AQD4HwCA/wAA+A8AgP8AAPwPAMD/AAD8DwDA/wAA/A8AwH8AcPwHgP9/APj//4D//x/4//+B//8f+P//gf//HwD+/wEA4B8AAAAAAAAA","aspect":0.67606},{"digit":"1","bits":"AAAAAAAAAOD/A8D/PwD8/wPA/z8A/P8DwP8/APz/A8D/PwA8/gMA4D8AAP4DAOA/AAD+AwDgPwAA/gMA4D8AAP4DAOA/AAD+AwDgPwAA/gMA4D8AAP4DAOA/APj//8H//x/8///B//8f/P//wf//H/z//8H//x8AAAAAAAAA","aspect":0.71642},{"digit":"1","bits":"AAAAAAAAAAAAAADwHwDg/wHA/x8A/P8BwP8fAPz/A8D/PwD8/wPA7z8AAP4DAOA/AAD+AwDgPwAA/gcA4H8AAPwHAMB/AAD8BwDAfwAA/AcAwH8AAPz/A/j/P+D//wP+/z/g//8D/v8/4P//A/7/AOAPAAAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"1","bits":"AAAAAAAAAADgBwCA/wMA/j8A+P8DwP8/APz/A8D/PwB8/wEA+B8AgP8BAPgfAID/AQD4HwCA/wEA+A8AgP8AAPgPAMD/AAD8DwDA/wAA/A8AwP8AAPwPAMB/AAD8BwDufwDw/wcA//8H8P//AP//DwD+/wAA4A8AAAAAAAAA","aspect":0.61111},{"digit":"1","bits":"AAAAAAAAAAD+BwDwfwDA/wcA/38A+P8HgP9/APj/B4D/fwB4/gcA4H8AAP4HAOB/AAD+BwDgfwAA/gcA4H8AAP4HAOB/AAD+BwDgfwAA/gcA4H8AAP4HAOB/AAD+BwDgfwAA/gcA4H8A+P//gP//D/j//4D//w8AAAAAAAAA","aspect":0.64706},{"digit":"1","bits":"AAAAAAAAAAD+AQDwHwDA/wEA/j8A8P8DwP8/APz/A8D/PwD8/wPA8z8AHP8DAPB/AAD+BwDgfwAA/gcA4H8AAP4HAOB/AAD+DwDg/wAA/A8AwP8AAPwPAMD/AAD8DwDA/wAA/P8D+P8/4P//A/7/P+D/fwD8BwAAAAAAAAAA","aspect":0.71831},{"digit":"1","bits":"AAAAAAAAAADwHwDA/wEA/x8A/P8BwP8fAPz/AcD/HwD+/wHg/x8APv8BAPAfAAD/AADwDwAA/wAA8A8AgP8AAPgPAID/AAD4DwCA/wAA+AcAgH8AAPgHgP9/APj/B4D//x/4//+B//8f+P//gf//HwD+/wEA4B8AAAAAAAAA","aspect":0.66667},{"digit":"1","bits":"AAAAAAAAAAD+AwD4PwDA/wMA/z8A+P8DwP8/APz/A8D/PwD8/wPAzz8AfPwDAMA/AAD8AwDAPwAA/AMAwD8AAPwDAMA/AAD8AwDAPwAA/AMAwD8AAPwDAMA/AAD8A8D//x/8///B//8f/P//wf//H/z//8H//x8AAAAAAAAA","aspect":0.69841},{"digit":"1","bits":"AAAAAAAAAAD+AAD4DwDA/wAA/h8A8P8BgP8fAPz/AcD/HwD8/wHA/x8AfP4BwOM/AAD+AwDAPwAA/AMAwD8AAPwDAMA/AAD8AwDAfwAA/AcAwH8AAPgHAID/P8D//wP//z/w//8D//8/8P//A/7/A+A/AAAAAAAAAAAAAAAA","aspect":0.75758},{"digit":"1","bits":"AAAAAAAAAADgHwAA/wEA+B8A4P8BgP8fAPz/AeD/HwD+/wHg/x8A/v8AwP8PAHz/AADwDwAA/wAA+A8AgP8AAPgPAIB/AAD4BwCAfwAA+AcAgH8AAPwHAN5/APD/BwD//wfw/38A//8H8P9/AP//BwD/fwAA8AcAAAAAAAAA","aspect":0.55714},{"digit":"1","bits":"AAAAAAAAAAD4BwDAfwAA/gcA8H8AgP8HAPx/AOD/B4D/fwD4/weA/38A+P8HAP9/AOD7BwCAfwAA+AcAgH8AAPgHAIB/AAD4BwCAfwAA+AcAgH8AAPgHAIB/AAD4BwD8/w/g//8A/v8P4P//AP7/D+D//wD+/w8AAAAAAAAA","aspect":0.64179},{"digit":"1","bits":"AAAAAAAAAAD8AQDgHwAA/wEA+B8AwP8BAP4fAPD/AYD/PwD8/wPA/z8A/P8DwP8/APj9AwDPPwAA/AMAwH8AAPwHAMB/AAD4BwCAfwAA+AcAgH8AAPgHAIB/DgD4/wH8/x/A//8B/P8fwP//Afz/H8D/PwD8AwAAAAAAAAAA","aspect":0.68571},{"digit":"1","bits":"AAAAAAAAAACAfwAA/gcA8H8AwP8HAP9/APj/B+D/fwD+/wfg/38A/v8DwP8/APj+A4DnPwAA/gMA4D8AAP8DAPAfAAD/AQDwHwAA/wEA8B8AAP8BAPAfAID/AQD4DwCA/wAA+A8AgP8AAPgPAID/AAD4DwCA/wAAAAAAAAAA","aspect":0.52239},{"digit":"1","bits":"AAAAAAAAAADAPwAA/gMA+D8AwP8DAP4/APD/A4D/PwD+/wPg/z8A/v8D4P8/APz/A4DvPwBw/gMA4D8AAP4DAOA/AAD+AwDgPwAA/gMA4D8AAP4DAOA/AAD+AwDgPwAA/gMA4D8AAP4DAOA/AAD+AwDgPwAA/gMAAAAAAAAA","aspect":0.5},{"digit":"1","bits":"AAAAAAAAAADwDwCA/wAA/A8A4P8AAP8PAPj/AMD/DwD+/wHw/x8A//8B8P8fAP//AeD/HwB8/wGA8x8AAP8DAOA/AAD+AwDgPwAA/gMA4D8AAP4DAOA/AAD+BwDAfwAA/AcAwH8AAPwHAMB/AAD8BwDAfwAA/AcAAAAAAAAA","aspect":0.56716},{"digit":"2","bits":"AAAAAAAAAMD/BwD+/wHg/38A/v8P4P//Af//H/D//wN//D/wgP8DAPA/AAD/AwDwPwCA/wMA/B8A8P8BgP8PAP5/APD/A4D/HwD+/wDw/wPA/x8A/P8BwP//D/z//8D//w/8///A//8P/P//APD/DwAA/wAAAAAAAAAAAAAA","aspect":0.76389},{"digit":"2","bits":"AAAAAAAAAMD/D8D//wP8/3/A//8P/P//wf//H/z//8P//z/8wP/DA/g/AAD/AwD4PwCA/wMA/D8A4P8BAP8fAPj/AMD/BwD+PwD4/wHA/w8A/n8A8P8DgP8PAPz//8P//z/8///D//8//P//w///P/z//8P//z8AAAAAAAAA","aspect":0.72059},{"digit":"2","bits":"AAAAAAAAAAAAAADwfwDg/x+A//8D/P9/wP//B/z//8D//w/85/+AD/wPeID/AAD8DwDA/wAA/gcA8H8AgP8DAPwfAMD/AAD+BwDwfwCA/wMA/P8/4P//A///P/D//wP//z/g//8D/v8/4P8fAP4BAAAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"2","bits":"AAAAAAAAAAAAAAD+fwDg/x8A/v8H4P//AP7+H+CH/wE+8D/gAf8DHvA/AAD/AwDwPwCA/wMA+D8AwP8BAP4fAPD/AID/BwD+HwD4/wDg/wOA/w8f/D/wwf//H/z//8D//w/8///A//8P/P//APD/DwAA/wAAAAAAAAAAAAAA","aspect":0.77778},{"digit":"2","bits":"AAAAAAAAAOD/B8D//wP8/3/A//8P/P//wR/+H/zA/8MP+D98gP/DB/g/AID/AwD4PwCA/wMA+D8AwP8BAPwfAOD/AAD/BwD4PwDg/wAA/wcA+D8+4P/gA/8DPvz//8P//z/8///D//8//P//w///P/z//8P//z8AAAAAAAAA","aspect":0.73529},{"digit":"2","bits":"AAAAAAAAAAAAAAD4fwDw/x/A//8D/P9/wP//B/zx/8AP/g98wP/AB/wPfMD/AAD8DwDA/wAA/AcA4D8AAP4DAPAfAID/AAD85wHgPx8A//AD+Mc/4P//A///P/D//wP//z/w//8D//8/8P8fAP4BAAAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"2","bits":"AAAAAAAAAAD4BwDg/wOA/38A/P8PwP//Af7/H+D//wP+9z/gP/4D/sE/AA7+AwDwPwCA/wMA/B8A4P8BgP8PAPx/APD/A4D/HwD8/wDg/wMA/x8A+H8AgP8DAPz/D8D//w/8///A//8P/P//wP//DwD+/wAA4A8AAAAAAAAA","aspect":0.73529},{"digit":"2","bits":"AAAAAAAAAAD/BwD8/wHg/z8A//8H+P//gP//D/j//8D/+B/8B//Bf/Af/Af/AQD4DwDA/wAA/g8A8H8AgP8HAPw/AOD/AYD/DwD8fwDA/wMA/h8A8H8AgP8DAPgfAMD//x/8///B//8f/P//wf//H/z//8H//x8AAAAAAAAA","aspect":0.70312},{"digit":"2","bits":"AAAAAAAAAAD+AwD8/wDg/x8A//8D+P8/gP//B/z/f8D//gf8x3/AP/gH/IN/wB/8BwDgfwAA/wMA8D8AgP8BAPwfAOD/AAD/BwD4PwDA/wEA/A8A4H8AAP7zH/D//wP//z/w//8D//8/8P//A///H/D/AwA/AAAAAAAAAAAA","aspect":0.73529},{"digit":"2","bits":"AAAAAAAAAAD8DwDg/wOA/38A/P8PwP//Af7/H+D//wP+4z/gH/wD/MA/AAD+AwDgPwAA/wMA+B8AwP8BAP4PAPD/AID/BwD8PwDw/wGA/wcA/D8A4P8BgP8PAPz/f8D//w/8///A//8P/P//wP//DwD+/wAA4A8AAAAAAAAA","aspect":0.73239},{"digit":"2","bits":"AAAAAAAAAAD/BwD4/wHg/z8A//8H8P//gP//D/j//8D/+A/8B//Bf/Af+AP/AQDwHwCA/wAA+A8AwP8AAP4HAPB/AID/AwD8HwDg/wAA/wcA+D8AwP8BAP4PAPD/f4D//x/8///B//8f/P//wf//H/z//8H//x8AAAAAAAAA","aspect":0.69118},{"digit":"2","bits":"AAAAAAAAAAD+AQD4fwDg/x8A//8D8P8/gP//B/z/f8B//Af8g3/AP/gH/IN/wB/4BwDAfwAA/AcA4D8AAP8DAPAfAID/AQD8DwDgfwAA/gMA8B8AgP/hAPz/H+D//wP+/z/w//8D//8/8P//A///P/D/BwB/AAAAAAAAAAAA","aspect":0.72222},{"digit":"2","bits":"AAAAAAAAAAD4BwDw/wPA/38A/v8P4P//Af7/P8D//wP4/z+AD/4DAOA/AAD+AwDgPwAA/wMA+D8AwP8BAP8PAPj/AMD/BwD+PwDw/wHA/wcA/j8A8P8BgP8PAPz//8D//x/8///B//8f/P//wf//HwD+/wAA4A8AAAAAAAAA","aspect":0.71831},{"digit":"2","bits":"AAAAAAAAAAD/BwD+/wHw/z/A//8H/P9/wP//D/z//4D//A/wg/8AHvgPAID/AAD4DwDA/wAA/g8A4H8AAP8HAPg/AMD/AQD+HwDw/wCA/wcA/D8A4P8BAP8PAPj//8H//x/8///B//8f/P//wf//H/z//8H//x8AAAAAAAAA","aspect":0.70149},{"digit":"2","bits":"AAAAAAAAAAD+AQD8fwDg/x+A//8D/P8/wP//B/z/f8D//gf4w38AH/gH4MB/AAD8BwDgPwAA/gMA8D8AgP8BAPwfAMD/AAD+BwDwPwCA/wEA+B8cwP//A/7/P/D//wP//z/w//8D//8/8P//A///AOAHAAAAAAAAAAAAAAAA","aspect":0.74648},{"digit":"3","bits":"AAAAAAAAAAAAAAD8fwDA/z8A/P8HwP//Afz/H8D//wP8/z/Awf8DAPA/AAD/A+D4PwD//wPw/x8A//8B8P8HAP9/APD/DwD//wEA/h8AgP+BA/Af/ID/wf/+H/z//8H//x/8///A//8P+P9/AP7/AwD/DwAAAAAAAAAAAAAA","aspect":0.8},{"digit":"3","bits":"AAAAAAAAAOD/D4D//wP4//+A//8P+P//gf//H/j//4F//x94gP8BAPgfAID/AYD/H4D//wH4/w+A/38A+P8PgP//Afj/H4D//wMA/j8AgP8DAPA/AAD/wwf4P/z//8P//z/8///B//8f/P//wP//B/z/PwD+fwAAAAAAAAAA","aspect":0.73913},{"digit":"3","bits":"AAAAAAAAAID/DwD//wH8/z/A//8H/P9/wP//D/z//8D//w/8wP+AA/wPAOD/APD/B4D/PwD4/weA//8A+P8fgP//Afj/P4D//wMA+D8AAP8DAPA/AID/gx//P/j//4P//x/4//+A//8P8P8/AP//AOD/AwAAAAAAAAAAAAAA","aspect":0.77143},{"digit":"3","bits":"AAAAAAAAAAAAAAD8fwDA/z8A/v8P4P//Af7+H+CH/wM+8D/gA/4DAPA/AAD/AwD4PwD8/wPA/x8A/P8AwP8HAPz/AAD8HwCA/wEA+B94AP+DB/A//AD/ww/4P/yB/8E//h/8///B//8P8P9/APz/AwD8DwAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"3","bits":"AAAAAAAAAOD/D4D//wP4/3+A//8P+Pf/gR/8H/iA/4EP+B94gP8BAPgfAMD/AQD/HwD+/wDg/wcA/n8A4P8PAP7/AQD8PwCA/wMA+D8AAP/DB/A/fAD/wwfwP/yA/8Mf/D/89//B//8f/P//wP//A8D/DwAAAAAAAAAAAAAA","aspect":0.75362},{"digit":"3","bits":"AAAAAAAAAAAAAADgfwDg/x/A//8D/P9/wP//B/zxf8AP/gd8wH/AB/wHfMB/AAD+BwDwfwDg/wMA/n8A4P8PAP7/AQD+PwCA/wMA8D8AAP8DAPA/8AD/Aw/wP/AB/wM/+D/w5/8B//8P8P9/AP//AeD/AwAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"3","bits":"AAAAAAAAAAD8AwDw/wGA/38A/P8P4P//Af7/H/D//wP/+z/wH/4D/OA/AAD+AwDwPwD8/wPA/x8A/P8BwP8PAPw/AMD/BwD8/wAA/h/8A//BP/Af/Af/wX/wH/zf/8H//x/4//8A//8P8P9/AP7/B4D/HwDAfwAAAAAAAAAA","aspect":0.73134},{"digit":"3","bits":"AAAAAAAAAAD/BwD8/wHg/z8A//8H+P//gP//D/j//8D/+A/8B//Af/APgAP/AAD4DwD+/wDg/wcA/n8A4P8DAP5/AOD/DwD+/wEA/h8AAP/BP/Af/AP+wX/wH/yP/8H//x/8//+B//8P8P//AP7/B8D/PwDw/wAAAAAAAAAA","aspect":0.70769},{"digit":"3","bits":"AAAAAAAAAAD8AwD4/wDg/z8A//8D+P9/gP//B/z/f8D//Q/8h//AP/gP/IP/gAf8BwD4fwDg/wMA/j8A4P8HAP7/AMD/HwD8/wPA+z8AAP4DcOA/8A/+g//gP/i//4P//z/w//8B//8f4P//APz/B4D/HwDAPwAAAAAAAAAA","aspect":0.73134},{"digit":"3","bits":"AAAAAAAAAAD8BwDw/wGA/38A/P8H4P//AP7/H/D//wH/8R/wD/4B/uAfAAD+AQDwHwD4/wGA/w8A+P8AwP8HAPw/AMD/BwD4fwAA/A/4Af/AP/AP/AP/wH/4D/zP/8D//wf4/3+A//8H8P8/AP7/AYD/DwDgHwAAAAAAAAAA","aspect":0.71429},{"digit":"3","bits":"AAAAAAAAAAD+DwD4/wHA/z8A/v8H4P//AP//D/D//wD/8Q/wD/8Af+AP8Af/AADwDwDA/wCA/w8A+H8AgP8DAPh/AID/DwD4/wEA/B8AAP8BPuAf+Af+gX/gH/gP/4H//x/4//8A//8P4P9/AP7/A4D/HwDwfwAAAAAAAAAA","aspect":0.68116},{"digit":"3","bits":"AAAAAAAAAAD+AwD4/wDg/x8A//8D8P8/gP//B/j/f8D//Af8h3/AP/gH/IN/wB/4BwDgfwDA/wMA/D8AwP8HAPz/AMD/HwD8/wEA+B8AAP4BAOAf8Af+gf/wH/if/4H//x/w//8A//8P4P9/APz/A4D/DwDgPwAAAAAAAAAA","aspect":0.69014},{"digit":"3","bits":"AAAAAAAAAAD+BwD8/wPg/38A/v8P4P//Afz/P8D//wP4/z+AB/4DAOA/AAD+AwDwPwD//wHw/x8A//8A8P8HAP8/APD/BwD//wAA/x8AgP8BAPAfOAD/gQ/4H/zH/8H//x/8///A//8P/P9/gP//B+D/HwDwfwAAAAAAAAAA","aspect":0.73913},{"digit":"3","bits":"AAAAAAAAAID/BwD+/wH4/3+A//8H+P//gP//D/D//wD+/A/gAf8AAPAPAID/AAD8DwD//wD4/weA/z8A+P8DgP9/APj/D4D//wEA/x8AgP8BAPAfAAD/gQPwH/jB/4H//x/4//+B//8P+P9/gP//A/j/HwD8fwAAAAAAAAAA","aspect":0.67647},{"digit":"3","bits":"AAAAAAAAAAD8AwD8/wDw/z+A//8H/P9/wP//B/z//4D//w/wg/8AH/gPAID/AAD8BwD8fwD4/wOA/z8A+P8PgP//AfD/HwD//wPw/z8AAP8DAOA/AAD+AwDwP/DB/wP//z/w//8B//8f4P//AP7/B+D/HwD8PwAAAAAAAAAA","aspect":0.72857},{"digit":"4","bits":"AAAAAAAAAAAAAAAA/AMA4P8AAP8PAPD/AID/DwD8/wDg/w8A//8A+P8PwP//AP7/B+D/fwD//Qf4z3/A//wH/Md/wP//B/z//8P//z/8///D//8//P//A/z/PwDg/wMA/h8A4D8AAP4DAOAfAAD+AQAAAAAAAAAAAAAAAAAA","aspect":0.82609},{"digit":"4","bits":"AAAAAAAAAAAAAAAAAAAA8D8AgP8DAPg/AMD/AwD+PwDg/wMA/z8A+P8DgP8/APz/A+D/PwD//wPw3z+A//wD/Oc/wD/+A/z//8P//z/8///D//8//P//w///P/z//wMA/gMAwD8AAPwDAMA/AAD8AwAAAAAAAAAAAAAAAAAA","aspect":0.83582},{"digit":"4","bits":"AAAAAAAAAAAAAAAA/wAA/A8A4P8AAP4PAPD/AQD/HwD4/wGA/x8A/P8BwP8fAP7/AeD/HwD//wPw7z+Af/4D+Oc/wD/+P/z//8P//z/8///D//8//P//w///P/z/f8D//AcAwH8AAPwHAMB/AAD8AQAAAAAAAAAAAAAAAAAA","aspect":0.82609},{"digit":"4","bits":"AAAAAAAAAAAAAAAA/AcAwP8AAP4PAPD/AID/DwD8/wDA/wcA/n8A8P8HgP9/APz/B+D/fwD+/gfw53+Af/4D/OM/wP/+A/z/P8D//z/8//8D+P8/APD/AwD/AQD/HwDw/wEA//8B8P8fAP//AQDwHwAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"4","bits":"AAAAAAAAAAAAAAAAAAAA8D8AAP8DAPg/AID/AwD8PwDg/wMA/j8A8P8DgP8/APj/A8D/PwD8/gPg7z8Af/4D8OM/gD/+A/zhP8D//z/8///D//8//P//AwD+AwDgPwAA/gMA/v8B4P8fAP7/AeD/HwAAAAAAAAAAAAAAAAAA","aspect":0.85294},{"digit":"4","bits":"AAAAAAAAAAAAAACAfwAA/AcAwP8AAP4PAOD/AAD/DwDw/wCA/w8A+P8AwP8PAPz/AeD/HwB+/wHw9x8AP/8B8PMfgB//Hfjx/8P//z/8///D//8//P8/wH/+AwDg/wMA/j8A/P8DwP8/APz/A8A/AAAAAAAAAAAAAAAAAAAA","aspect":0.8169},{"digit":"4","bits":"AAAAAAAAAAAAAAAA8AMAgP8AAPwPAOD/AAD/DwDw/wCA/w8A/P8A4P8PAP//APj/D8D/fwD8/wfgv38A//kH+I9/wH/4B/z/f8D//w/8///D//8//P//w///PwD+/wMA/D8AwD8AAPwDAMAfAAD8AQDAHwAAAAAAAAAAAAAA","aspect":0.78462},{"digit":"4","bits":"AAAAAAAAAAAAAAAA/gMA4D8AAP8DAPg/AID/AwD8PwDg/wMA/j8A8P8DAP8/APj/A8D/PwD8+wPgnz8A//kD8I8/gH/4A/yHP8D//z/8///D//8//P//w///P/z//8P//z8AgD8AAPgDAIA/AAD4AwCAPwAAAAAAAAAAAAAA","aspect":0.79365},{"digit":"4","bits":"AAAAAAAAAAAAAAAA/wAA+A8AgP8AAPwPAMD/AAD+HwDg/wEA/x8A8P8BgP8fAPj/AcD/HwD8/wHg3x8A/vwD8M8/AH/8A/jH/4M//j/8///D//8//P//w///P/z//8P//wf8j38AAPgHAIB/AAD4BwCAfwAAAAAAAAAAAAAA","aspect":0.79688},{"digit":"4","bits":"AAAAAAAAAAAA/gEA8B8AgP8BAPwfAOD/AQD/HwD4/wHA/x8A/v8A8P8PgP//APz/D+D//wD/9w/4P//A//EP/B9/wP//B/z//8P//z/8///D//8/8P//AwD+PwCA/wEA+AMAgD8AAPwDAMA/AAD8AwCAPwAAAAAAAAAAAAAA","aspect":0.75},{"digit":"4","bits":"AAAAAAAAAAAAAAAA+AcAwH8AAP4HAPB/AAD/BwD4fwDA/wcA/n8A4P8HAP9/APj/B8D/fwD8/wfgv38A//kH+J9/wP/4B/z//8P//z/8///D//8//P//g///P/D//wEA+AcAgH8AAPgHAIB/AAD4BwCAfwAAAAAAAAAAAAAA","aspect":0.77612},{"digit":"4","bits":"AAAAAAAAAADgDwAA/wEA8B8AgP8BAPgfAMD/AQD8HwDg/wEA/x8A8P8DgP8/APj/A8D/PwD8+wPgvz8A//kD8I8/gP/4P/j//8P//z/8///D//8//P//w///H/j/f4A/8A8AAP8AAPAPAAD/AADgDwAAfgAAAAAAAAAAAAAA","aspect":0.76471},{"digit":"4","bits":"AAAAAAAAAAAAfgAA8B8AgP8BAPwfAOD/AQD/HwDw/wCA/w8A/P8A4P8PAP//APj/D8D//wD8/w/gv/8A//kH+J9/wP/7B/z/f8D//z/8///D//8//P//w///PwD8/wMA/D8A4D8AAP4DAOA/AAD+AwDAPwAAAAAAAAAAAAAA","aspect":0.75},{"digit":"4","bits":"AAAAAAAAAADAfwAA/AcA4H8AAP8HAPB/AID/BwD8fwDA/wcA/n8A8P8HAP9/APj/B8D/fwD8/wfg/38A//0H8M9/gP/8B/z//8P//z/8///D//8//P//w///P/z//4P//z8AwH8AAPwHAMB/AAD8BwDAfwAAAAAAAAAAAAAA","aspect":0.75758},{"digit":"4","bits":"AAAAAAAAAADwDwAA/wAA+A8AgP8AAPwPAMD/AQD+HwDg/wEA/x8A8P8BgP8fAPj/AcD/HwD8/wHg/z8A/v8D8O8/AP/8H/jn/4P//z/8///D//8//P//w///P/z//4D//wf4gH8AAPgHAIB/AAD4BwCAHwAAAAAAAAAAAAAA","aspect":0.76471},{"digit":"5","bits":"AAAAAAAAAMAfAAD8/wHA//8D/P8/wP//A/z/P8D//wP+/z/g//8D/gMf4P8HAP7/AeD/fwD+/w/w//8B//8f8P//Aw7+PwCA/wMA8D84AP+DB/A//IH/w//+P/z//8P//x/8///B//8P+P9/AP7/AwD/DwAAAAAAAAAAAAAA","aspect":0.76056},{"digit":"5","bits":"AAAAAAAAAPj//4D//w/4//+A//8P+P//gP//D/j//4D//w/4BwCA/z8A+P8fgP//B/j//4D//w/4//+B//8f+P//gw/8PwCA/wMA8D8AAP/DAfg/fID/w3//P/z//8P//x/8///B//8P/P9/wP//AeD/BwAAAAAAAAAAAAAA","aspect":0.75},{"digit":"5","bits":"AAAAAAAAAAAAPwDw/wP8/z/A//8D/P8/wP//A/z/P8D//wP4/wCAfwAA+P8PgP//A/j/f4D//w/4//+B//8f8P//Af/+P/CB/wMH8D8AAP8DAPA/AID/Az/+P/D//wH//x/w//8A//8H8P8/AP//AOD/AwAAAAAAAAAAAAAA","aspect":0.76389},{"digit":"5","bits":"AAAAAAAAAMAfAAD8/wHA//8D/P8/wP//A/z/P8D//wP8/z/gw/8DPgAc4P8BAP7/AOD/PwD+/wfg//8APvwfAID/AQDwPwAA/wMA8D8AAP/DB/A/fAD/wwf4P/yA/8MP/D/84f/B//8f/P//gP//B+D/PwDw/wAAAAAAAAAA","aspect":0.73239},{"digit":"5","bits":"AAAAAAAAAPj//4D//w/4//+A//8P+P//gP//D/j//4D//wf4AACADwcA+P8PgP//A/j/f4D//w/48/+BH/wf8ID/AwD4PwCA/wMA8D8AAP8DAPA/fAD/wwf4P3yA/8MP+D/8wf/B//8f/P//wP//B/z/PwD8fwAAAAAAAAAA","aspect":0.73529},{"digit":"5","bits":"AAAAAAAAAADwPwD//wP8/z/A//8D/P8/wP//A/z/P8D/PwD4AwCADwAA+P8PgP//A/j/f4D//w/49/+BH/wf8ID/Awf4PwCA/wMA8D8AAP8DAPA/8AD/gw/wP/iB/4E//B/w//8A//8H8P8/AP//AeD/AwAAAAAAAAAAAAAA","aspect":0.74648},{"digit":"5","bits":"AAAAAAAAAMA/AAD8/wPA//8B/v8f4P//Af7/H+D//wH+/R/gHwAA/wEA8P8DAP//APD/PwD//wf4/3+A//8P+P//gP/8DwCA/wEA8B8cAP/BP/Af/AP/wX/4D/zP/8D//w/4/3+A//8H8P8/AP7/AYD/DwDgPwAAAAAAAAAA","aspect":0.71642},{"digit":"5","bits":"AAAAAAAAAPD//wD//w/4//+A//8P+P//gP//D/j//4B/AAD4BwCAfwAA+P8fgP//A/j/f4D//w/4//+B//8f+P//g//4P/gH/wMA4D8AAP4DPOA//AP+w3/wP/yP/8P//x/8//+B//8P8P//AP//B8D/HwDwfwAAAAAAAAAA","aspect":0.71875},{"digit":"5","bits":"AAAAAAAAAADwHwD//wH8/z/A//8D/P8/wP//A/z/D8D/AAD8AwDAPwAA/PsPwP//A/z/f8D//wf8///A//8P/P//gf/5H/gH/4E/8B8AAP4BAOAf4Af/gf/wH/jf/4H//x/4//8A//8H8P9/AP7/A4D/DwDgHwAAAAAAAAAA","aspect":0.70149},{"digit":"5","bits":"AAAAAAAAAAB+AADg/wcA//8D8P8/AP//A/D/P4D//wP4/x+AP/gA/AMAwD8AAPx/AOD/HwD+/wPg/38A/v8P4P//APj/DwCA/wEA8B8AAP4BAOAfAAD/AR/wH/iH/8D//w/8///A//8H+P8/AP//AcD/DwDwPwAAAAAAAAAA","aspect":0.72857},{"digit":"5","bits":"AAAAAAAAAID//wD4/w+A//8A/P8PwP//APz/D8D/fwD8AQDAHwAA/gEA4P8DAP7/AeD/PwD+/wfg//8A/v8P4P//Afz8HwAA/wEA4B8AAP4BAOAfAAD+AR7wH/CH/wH//w/4//+A//8H+P9/AP//A8D/DwDwPwAAAAAAAAAA","aspect":0.67647},{"digit":"5","bits":"AAAAAAAAAAD4DwD//wH4/x+A//8B+P8fgP//APj/B4D/BwD4AwCAPwAA+AMAgP9/APj/H4D//wP4/z+A//8H+P9/gP//D+DB/wAA+A8AAP8AAPAPAID/AAD4D/DDfwD//wf4/z+A//8D+P8fgP//APD/AwD4DwAAAAAAAAAA","aspect":0.61972},{"digit":"5","bits":"AAAAAAAAAAD/AAD4/weA//8B+P8fgP//Afj/H8D//wH8/x/A//8B/AMAwD8AAP5/AOD/HwD+/wPg/38A/v8P4P//APz/HwDg/wEA+B8AAP8BAPAfeAD/gR/4H/jP/4H//w/4//+A//8H+P9/gP//A+D/HwDwfwAAAAAAAAAA","aspect":0.68116},{"digit":"5","bits":"AAAAAAAAAOD/fwD+/wfw/38A//8H8P9/AP//B/D/fwD//wPwDwAA/wAA8A8AAP//APD/PwD//wfw//8A//8P8P//Af//H8DB/wEA+B8AAP8BAPAfAAD/gQf4H/jj/4H//w/4//+A//8H+P9/gP//A/j/DwD+PwAAAAAAAAAA","aspect":0.67164},{"digit":"5","bits":"AAAAAAAAAADwHwD//wH4/x+A//8B+P8fgP//Afj/H4D//wD4DwCAfwAA+AcAgP//APj/P4D//wf4//+A//8P+P//Af//H/DP/wEA8B8AAP8BAPAfAAD/AQD4H/Dh/wH//x/w//8A//8H8P9/AP//A+D/DwD+HwAAAAAAAAAA","aspect":0.65714},{"digit":"6","bits":"AAAAAAAAAAD4HwDg/w+A//8B/P8/4P//A/7/P/D//wP//z/4P/CD/x8c+P8fwP//A/z/f8D//w/8///B//8f/P//w//5P/wP/8P/8D/8D//D//A//I//g///H/j//wH//x/w//8A/v8HwP8/APD/AQD8BwAAAAAAAAAAAAAA","aspect":0.77143},{"digit":"6","bits":"AAAAAAAAAAAAAADA/wMA//8A+P8fwP//Af7/H/D//wH//x/4f/iB/wEA+P8PwP//A/z/f8D//w/8///B//8//P//w///P/wf/8P/4D/8D/7D/+A/+B//g//7P/j//wP//x/w//8B/v8PwP9/APj/AwD+DwAAAAAAAAAAAAAA","aspect":0.78261},{"digit":"6","bits":"AAAAAAAAAAAAAADA/wEA/z8A+P8D4P9/AP7/B/D/f4D//wf4f3iA/wEA/P8PwP//A/z/f8D//w/8///B//8f/P//w///P/wf/8P/4D/8D/6D/+E/+B/+g//7P/D//wP//x/g//8B/v8PwP9/APj/AQD+BwAAAAAAAAAAAAAA","aspect":0.8},{"digit":"6","bits":"AAAAAAAAAAAAAADA/wEA//8A+P8/wP//A/7/P/B/+AP/Az/4H+CD/wEe+P8HgP//Afz/f8D//w/8///A//kf/A//wf/wH/wP/8H/8B/8B//Bf/gf/If/wX/4H/iH/4H//B/w//8A/v8HwP9/APj/AQD8BwAAAAAAAAAAAAAA","aspect":0.78571},{"digit":"6","bits":"AAAAAAAAAAAAAADA/wcA//8B+P8fwP//Af7vH/A/+AH/AR/4D/CB/wAA+P8PwP//A/z//8D//w/8///B//k//B//w//wP/wP/8P/8D/8D//D//A/+A//g//wP/gf/wP/8T/w//8B/v8PwP//APj/AwD+DwAAAAAAAAAAAAAA","aspect":0.78261},{"digit":"6","bits":"AAAAAAAAAAAAAADA/wMA/38A/P8H4P9/AP//B/AffoD/wAf4BwCAfwAA/PcPwP//A/z/f8D//w/8///B//kf/I//w//wP/wP/8P/8D/8D/+D//A/+B/+g//hP/gf/wP/8x/w//8B/v8PwP9/APj/AwD+DwAAAAAAAAAAAAAA","aspect":0.8},{"digit":"6","bits":"AAAAAAAAAAD8BwDw/wGA/38A/P8H4P//AP7/D/D//wH/8x/wH/6B/+Af+O8BgP//APj/H8D//wP8/3/A//8P/P//wP/8D/yH/8B/8A/8A//AP/AP/If/wH/4D/jf/4D//wfw/38A//8H4P8/APz/AYD/DwDAPwAAAAAAAAAA","aspect":0.71212},{"digit":"6","bits":"AAAAAAAAAAD+BwD4/wHA/z8A/v8H8P//AP//D/j//4D/+Q/4D//Af+AA/OcDwP//Afz/P8D//wf8///A//8P/P//wf/9H/wP/8F/8B/8B/7Bf+Af/Af/gf/wH/if/4H//x/w//8A//8P4P9/APz/A4D/HwDgfwAAAAAAAAAA","aspect":0.69231},{"digit":"6","bits":"AAAAAAAAAAD+AQD4fwDA/w8A/v8B8P8/gP//A/j/P8D//gP8xx/APwAA/OMDwP//Afz/P8D//wf8/3/A//8P/P//wP/9H/yP/8F/8B/8B//Bf+Af+A/+gf/wH/if/wH//x/w//8A/v8P4P9/APz/A4D/HwDgfwAAAAAAAAAA","aspect":0.71212},{"digit":"6","bits":"AAAAAAAAAACA/wAA/A8A4P8AAP8PAPh/AMD/AwD+HwDw/wCA/wcA/D8A4P8BAP7/APD/P4D//wf4///A//8P/P//wf/9H/wH/8E/8B/8A/7BP+Af/AP/wX/wH/zP/4H//w/4//8A//8H8P8/AP7/AYD/DwDgHwAAAAAAAAAA","aspect":0.70588},{"digit":"6","bits":"AAAAAAAAAADgPwAA/wMA+D8AwP8BAPwPAOD/AAD/BwDwPwCA/wEA/A8A4P8AAP7/APD/PwD//wf4//+A//8P/P//wf//H/yP/8F/8B/8A/7BP+Af/AP+wT/wH/yH/4H//w/4//+A//8H8P9/AP7/A8D/DwDwfwAAAAAAAAAA","aspect":0.70588},{"digit":"6","bits":"AAAAAAAAAADwDwDA/wAA/A8A4H8AAP4DAPA/AID/AQD4DwDA/wAA/AcA4H8AAP5/APD/HwD//wP4/3+A//8P/P//wP//H/yP/8F/8B/8A/7BP+Af/AP+wX/wH/yH/4H//w/4//8A//8H8P8/AP7/AcD/DwDwPwAAAAAAAAAA","aspect":0.7},{"digit":"6","bits":"AAAAAAAAAADw/wDg/x8A//8B+P8fwP//Af7/H+D//wH/Dx/wPwCA/wEA+P8HgP//Afj/P8D//wf8///A//8P/P//wf/9H/wP/8F/8B/8B//Bf/Af/Af/wf/4H/j//4D//w/4//8A//8H4P9/APz/A4D/DwDAPwAAAAAAAAAA","aspect":0.69118},{"digit":"6","bits":"AAAAAAAAAAD4fwDg/weA/38A/P8H4P9/AP7/B/D/fwD/DwD4HwCA/wAA+OcDwP//Afz/P8D//wf8///A//8P/P//wf//H/yP/8F/8B/8B//Bf/Af/Af/wf/wH/jf/4H//x/4//8A//8P4P9/APz/A4D/HwDgfwAAAAAAAAAA","aspect":0.69118},{"digit":"6","bits":"AAAAAAAAAADwDwDg/wEA/x8A/P8B4P8fAP//AfD/H4D/DwD4HwCA/wAA/AcAwL//APz/P8D//wf8/3/A//8P/P//wP//D/yf/8H/8B/8B//Bf/Af/A//gf/wH/if/4H//w/w//8A//8P4P9/APz/A4D/HwDgfwAAAAAAAAAA","aspect":0.7},{"digit":"7","bits":"AAAAAAAAAPgHAID/fwD8///D//8//P//w///P/z//8P//z8A/v8DAPwfAOD/AAD+DwDwfwCA/wcA+D8AwP8BAPwfAOD/AAD/BwDwfwCA/wMA+D8AwP8BAP4PAOD/AAD/BwD4fwCA/wMA+B8AgP8BAOAPAAAAAAAAAAAAAAAA","aspect":0.75714},{"digit":"7","bits":"AAAAAAAAAPz//8P//z/8///D//8//P//w///P/z//8P//z8AwP8BAPwfAMD/AAD+DwDgfwAA/wcA8D8AgP8DAPgfAMD/AQD8HwDg/wAA/g8A4H8AAP8HAPA/AID/AwD4HwDA/wEA/A8A4P8AAP4HAOB/AAAAAAAAAAAAAAAA","aspect":0.76119},{"digit":"7","bits":"AAAAAAAAAAAA/APA/z/8///D//8//P//w///P/z//8P//z/8///Bf/gfAID/AQD8DwDA/wAA/A8A4H8AAP4HAOB/AAD/AwDwPwAA/wMA8B8AgP8BAPgfAID/AAD8DwDA/wAA/A8A4H8AAP4HAOB/AAD+AwDgHwAAAAAAAAAA","aspect":0.72222},{"digit":"7","bits":"AAAAAAAAAPgHAID/fwD4//+D//8/+P//g///P/z//8P//z/8/v/BB+AffAD+gQfwDwCAfwAA+AcAwD8AAP4BAOAfAAD/AAD4BwCAfwAA/AMA4B8AAP4BAPAPAIB/AAD4BwDAPwAA/gEA4B8AAP4AAOAHAAAAAAAAAAAAAAAA","aspect":0.75714},{"digit":"7","bits":"AAAAAAAAAPz//8P//z/8///D//8//P//w///P/z//8P//z98APzBB+AffAD+wAfwDwAAfwAA+AcAgD8AAPwDAMAfAAD+AQDgDwAA/wAA8AcAgH8AAPgDAMA/AAD8AQDgHwAA/gAA8A8AAH8AAPAHAAA/AAAAAAAAAAAAAAAA","aspect":0.74627},{"digit":"7","bits":"AAAAAAAAAAAA/gDg/x/8///B//8f/P//wf//H/z//8H//x/8///Af+AP+AD+gA/gB/gAf4AP8AcAAD8AAPgDAIA/AAD4AQDAHwAA/AEAwA8AAP4AAOAPAAB/AADwBwAAfwAA+AMAgD8AAPgBAIAfAAD4AQCADwAAAAAAAAAA","aspect":0.70833},{"digit":"7","bits":"AAAAAAAAAPADAID/HwD4//+B//8f+P//gf//H/j//wH+/x8A4P8BAPgPAMD/AAD+BwDwPwCA/wEA+A8AwP8AAP4HAOA/AAD/AwD4HwCA/wAA/A8AwH8AAPwHAOB/AAD+AwDgPwAA/gEA8B8AAP8BAPAfAAD+AQAAAAAAAAAA","aspect":0.68182},{"digit":"7","bits":"AAAAAAAAAPj//4H//x/4//+B//8f+P//gf//H/j//wEA8B8AgP8AAPwPAMB/AAD+AwDgPwAA/wEA+B8AgP8AAPwPAMB/AAD+BwDgPwAA/gMA8B8AAP8BAPAfAAD/AQD4DwCA/wAA+A8AgP8AAPgPAID/AAD4DwAAAAAAAAAA","aspect":0.68254},{"digit":"7","bits":"AAAAAAAAAAAA/ADA/x/4//+B//8f+P//gf//H/j//4H//x/4H/8AAPgPAIB/AAD8BwDAPwAA/gMA4B8AAP4BAPAfAAD/AAD4DwCA/wAA+AcAgH8AAPgHAMB/AAD8BwDAfwAA/AMAwD8AAPwHAMB/AAD8BwDAPwAAAAAAAAAA","aspect":0.67164},{"digit":"7","bits":"AAAAAAAAAPgDAID/PwD4//+B//8/+P//g///P/j//wP+/z8A4P8BAPgfAMD/AAD8DwDgfwAA/wMA8D8AgP8BAPwPAMD/AAD+BwDwPwAA/wMA+B8AwP8AAPwPAOB/AAD/BwDwPwCA/wEA/B8AwP8AAPwHAMA/AAAAAAAAAAAA","aspect":0.72464},{"digit":"7","bits":"AAAAAAAAAPz//8H//x/8///B//8f/P//wf//H/z//wEA+A8AgP8AAPwHAMB/AAD+AwDgPwAA/wEA8B8AgP8AAPgPAMB/AAD8BwDgPwAA/gMA8D8AAP8BAPgfAID/AAD8DwDAfwAA/gcA4D8AAP8DAPAfAAD/AAAAAAAAAAAA","aspect":0.70149},{"digit":"7","bits":"AAAAAAAAAAAA/gHg/x/4//+B//8f+P//gf//H/j//4H//x/wD/8AAPAPAID/AAD4BwCAfwAA/AcAwD8AAP4DAOA/AAD+AQDwHwAA/wEA8A8AgP8AAPgPAIB/AAD8BwDAfwAA/gMA4D8AAP4DAPAfAAD/AQDwBwAAAAAAAAAA","aspect":0.65278},{"digit":"7","bits":"AAAAAAAAAPwDAMD/HwD8///B//8f/P//wf//H/z//8H//x8A/v8BAPwPAMB/AAD+BwDwPwAA/wMA+B8AgP8AAPwPAOB/AAD+BwDwPwCA/wMA+B8AwP8AAPwPAOB/AAD/BwDwPwCA/wMA+B8AgP8AAPgPAAB/AAAAAAAAAAAA","aspect":0.71014},{"digit":"7","bits":"AAAAAAAAAPz//8P//z/8///D//8//P//w///P/z//8P//x8AgP8BAPgfAID/AAD8DwDAfwAA/gcA4D8AAP8DAPAfAID/AQD4HwDA/wAA/A8A4H8AAP4HAOA/AAD/AwDwPwCA/wEA+B8AwP8AAPwPAMB/AAD8BwAAAAAAAAAA","aspect":0.72727},{"digit":"7","bits":"AAAAAAAAAAAA/gHg/x/8///B//8f/P//wf//H/z//8H//x/8//+AD/gPAID/AAD4BwDAfwAA/AcAwD8AAP4DAOA/AAD+AwDwHwAA/wEA8B8AgP8AAPgPAID/AAD8BwDAfwAA/AcAwH8AAP4DAOA/AAD+AwDgDwAAAAAAAAAA","aspect":0.69014},{"digit":"8","bits":"AAAAAAAAAAAAAADgPwDA/z8A/v8H4P//AP//H/D//wP//z/w//8D//E/8B//A///P+D//wP+/x/g//+A//8H+P9/wP//D/z//8H/+B/8B//Bf/Af/I//wf//H/z//8H//w/4//8A//8P4P9/APj/AwD8BwAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"8","bits":"AAAAAAAAAAAAAADw/wDg/38A//8P8P//gP//H/j//4H//x/4n/+B//Af+A//gf//H/j//wH//w/g/38A//8P+P//gf//H/z//8P/8D/8B//Df+A//A//w//5P/z//8P//z/4//+B//8f8P//AP7/BwD/DwAAAAAAAAAAAAAA","aspect":0.78261},{"digit":"8","bits":"AAAAAAAAAAAAAADAfwDA/z8A/v8H8P9/gP//D/z//8D//w/8///A//gP/I//wP//D/z/f4D//wfw/38A/v8f4P//Af//P/j//4P/8T/4D/6D/+A/+B//g///P/j//4P//z/w//8B//8P4P9/APz/AQD+AwAAAAAAAAAAAAAA","aspect":0.78873},{"digit":"8","bits":"AAAAAAAAAAAAAADgfwCA/z8A/P8H4P//Af//H/A//wP/4z/wP/4D//E/8B//A/7zP+D//wH+/x/w//+A//8H+P//wP/4H/wP/8H/8B/8B//Bf/Af/If/wX/4H/yP/4H//x/w//8A/v8HgP8/AMD/AAAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"8","bits":"AAAAAAAAAAAAAADw/wHA/38A/v8P8P//gP//H/if/4H/8R/4D/+B//Af+B//gf/5H/D//wH//w/g/38A//8P+P//gf/5H/wP/8P/8D/8D/7D/+A//A/+w//wP/wP/8P/8D/4v/+D//8f8P//APz/BwD/HwAAAAAAAAAAAAAA","aspect":0.7971},{"digit":"8","bits":"AAAAAAAAAAAAAADgfwDA/x8A/v8D+P9/gP//B/zP/8B//A/8x//A//gP/I//wP/8B/j/f4D//wPw//8A/v8f8P//gf/xP/gP/4P/8D/4D/6D/+A/+B/+g//hP/gf/4P//x/w//8A/v8HwP8fAPA/AAAAAAAAAAAAAAAAAAAA","aspect":0.80282},{"digit":"8","bits":"AAAAAAAAAAD8AwD4/wHA/z8A/v8H4P//AP//H/D//wH/8R/wH/4B/+Af8A/+Af/xH+D//wH+/w/A//8A//8H+P8/gP//B/z//8B/+A/8B//AP/AP/AP/wD/4D/yH/8D//w/4//+A//8H8P9/AP7/A4D/HwDgPwAAAAAAAAAA","aspect":0.71642},{"digit":"8","bits":"AAAAAAAAAID/BwD8/wHw/z8A//8H+P//gP//D/zf/8B/+A/8B//Af/AP/If/gP/4D/j//4D//wfw/z8A/v8D8P9/gP//D/z//8D/+B/8B//BP/Af/AP/wX/wH/wH/8H//R/8//+A//8P+P9/AP//B+D/HwD4fwAAAAAAAAAA","aspect":0.70769},{"digit":"8","bits":"AAAAAAAAAAD+AwD8/wDg/x8A//8D+P8/wP//B/z/f8B//Af8w3/AP/gH/Id/wH/8B/z/P4D//wP4/z8A//8H4P//AP//D/D//4H/8B/4B/+Bf+Af+Af+gf/gH/gP/4H//x/4//8B//8P8P9/AP7/A4D/DwDgHwAAAAAAAAAA","aspect":0.71642},{"digit":"8","bits":"AAAAAAAAAAD+BwDw/wGA/z8A/P8H4P//AP7/D+D//wH/8R/wD/4B/+Af8A/+Af7xH+D//wD+/w/g/38A//8H+P8/gP//B/z//8D//A/8B//AP/AP/AP/wH/4D/zP/8D//w/4//+A//8H8P8/AP7/AYD/DwDgPwAAAAAAAAAA","aspect":0.71429},{"digit":"8","bits":"AAAAAAAAAAD+BwD4/wHA/z8A/v8H4P//AP//D/D//wD/8Q/wD/8A/+AP8A//AP/xD/D//wD+/w/g/38A/P8H4P//AP//D/j//4H/+R/4D/+Bf+Af+Af+gX/gH/gP/4H//x/4//8B//8P8P//AP7/B4D/HwDg/wAAAAAAAAAA","aspect":0.68116},{"digit":"8","bits":"AAAAAAAAAAD+AAD8fwDg/w8A//8B+P8/gP//A/z/P8B//gf8w3/AP/gH/IN/wH/8A/z/P4D//wP4/z8A//8H4P//AP//D/j//4H/+R/4B/+Bf+Af+Af+gX/wH/iP/4H//x/4//8A//8P8P9/AP7/A4D/DwDgHwAAAAAAAAAA","aspect":0.69014},{"digit":"8","bits":"AAAAAAAAAAD8AwDw/wHA/z8A/P8H4P//AP7/H+D//wH++x/gH/4B/vEf4L//Af7/H+D//wD8/w+A/38A/v8D8P8fgP//A/j/f8D//wf8z//Af/gP/AP/wH/wD/yP/8D//w/8//+A//8H8P9/AP7/A8D/DwDgPwAAAAAAAAAA","aspect":0.7},{"digit":"8","bits":"AAAAAAAAAAD/BwD8/wHg/z8A//8H+P//gP//D/j//4D/+A/4B/+A//gP+N//gP//D/D/fwD//wPg/x8A/P8B8P8/gP//B/j//8D//w/8z//Bf/gf/AP/wT/wH/wH/8H//x/8//+B//8P+P9/AP//B+D/HwD4fwAAAAAAAAAA","aspect":0.69118},{"digit":"8","bits":"AAAAAAAAAAD+AQD8fwDg/x8A//8B+P8/gP//A/z/P8D//gP8xz/Af/wD/O8/wP//A/j/H4D//wHw/w8A/v8DwP9/AP7/D/D//wD//x/4n/+B//Af+Af+gX/wH/iP/4H//x/4//8A//8P8P9/AP7/A8D/DwDgHwAAAAAAAAAA","aspect":0.71429},{"digit":"9","bits":"AAAAAAAAAAD+AwD4/wDA/z8A/v8H8P//gP//D/j//4H//x/8H//D//A//A//w//wP/wP/8P/+T/8//+D//8/+P//A///P+D//wP8/z+A//+Bg/8f/MD/wf//D/z//8D//wf8/3/A//8D+P8fAP9/AID/AQAAAAAAAAAAAAAA","aspect":0.77143},{"digit":"9","bits":"AAAAAAAAAAAAAADwfwDA/x8A/v8D8P9/gP//D/j//4H//x/8n//B//A//A//w3/wP/wP/8P/+D/8///D//8/+P//g///P/D//wP+/z/A//8D4P8/AID/AR/+H/D//wH//w/w/38A//8H8P8/AP//AMD/AwAAAAAAAAAAAAAA","aspect":0.78261},{"digit":"9","bits":"AAAAAAAAAAAAAADgfwDA/w8A/v8D8P9/gP//B/j//8D//w/83//Bf/gf/If/wX/wP/yH/8P/+D/8///D//8/+P//g///P/D//wP+/z/A//8D8P8/AID/AR7+H+D//wH+/w/g/38A/v8D4P8fAPz/AID/AQAAAAAAAAAAAAAA","aspect":0.8},{"digit":"9","bits":"AAAAAAAAAAAAAADgPwCA/x8A/P8D4P9/AP//D/A//4H/4R/4H/6D/+E/+B/+g//gP/gP/4P/8D/4D/+D//A/+J//A///P/D//wP+/z+A//8D4P8feID/wQ/4H/yA/8Af/A/8/3/A//8D/P8fAP//AID/AwAAAAAAAAAAAAAA","aspect":0.78571},{"digit":"9","bits":"AAAAAAAAAAAAAADwfwDA/x8A//8D8P9/gP//D/yP/8D/8B/8D//B//Af/A//w//wP/wP/8P/8D/8D//D//g//J//g///P/D//wP//z/A//8D8P8fAAD/gQ/wH/iA/4Af/A/453+A//8D+P8fgP//AOD/AwAAAAAAAAAAAAAA","aspect":0.78261},{"digit":"9","bits":"AAAAAAAAAAAAAADwfwDA/x8A/v8D8P9/gP//B/jP/8B/+A/8h//Bf/gf/If/wf/wP/wP/8P/8D/8D//D//E/+J//g///P/D//wP+/z/A//8D8O8/AAD+AQDgH+AD/wF++A/g//8A/v8H4P8/AP7/AMD/AwAAAAAAAAAAAAAA","aspect":0.8},{"digit":"9","bits":"AAAAAAAAAAD8AQD4/wDA/x8A/v8D8P9/AP//D/D//4D//w/4D/+B//Af+Af+gX/gH/gH/4H/8B/4n/+B//8f8P//Af//H+D//wH8/x+A//8A3P8P/IP/wD/8D/znf8D//wf4/z+A//8D8P8fAP//AMD/BwDwHwAAAAAAAAAA","aspect":0.71212},{"digit":"9","bits":"AAAAAAAAAAD/BwD8/wDg/z8A//8D+P9/gP//D/z//8D//A/8h//Bf/Af/AP/wT/wH/wH/8F/+B/83//B//8f+P//gf//H/D//wH+/x/A//8B4PMf8AP/gX/4D/jP/4D//w/4/3+A//8H8P8/AP7/AcD/DwD4PwAAAAAAAAAA","aspect":0.69231},{"digit":"9","bits":"AAAAAAAAAAD+AQD4fwDg/w8A//8B+P8/gP//A/z/f8D//gf8x//AP/gP/IP/wD/wD/wH/8B/+B/8//+B//8f+P//gf//H/D//wH+/x/A//8B8OMfAA//Af7wD/Df/wD//w/w/38A/v8HwP8/APz/AYD/DwDgHwAAAAAAAAAA","aspect":0.71642},{"digit":"9","bits":"AAAAAAAAAAD/BwD4/wHg/z8A//8H8P//gP//D/j//8H/+B/8B//Bf+Af/AP+wX/gH/wH/8H/+R/8//+B//8P+P//AP//D+D/fwD8/wcA/j8AwP8BAP4PAPB/AID/AwD8HwDg/wGA/w8A/H8AwP8DAPwfAAD+AAAAAAAAAAAA","aspect":0.69118},{"digit":"9","bits":"AAAAAAAAAAD+BwD4/wHA/z8A/v8H8P//AP//D/j//4H/8R/4D/6Bf+Af+Af+gX/gH/gP/4H/+R/4//8B//8f8P//Af7/D8D//wD4/wcA/n8AAP8DAPgfAMD/AQD8DwDgfwAA/wMA+D8AwP8BAPwPAMD/AAD8BwAAAAAAAAAA","aspect":0.67647},{"digit":"9","bits":"AAAAAAAAAAD4AwDw/wGA/z8A/P8H4P//AP//D/D//4H/+R/4D/+Bf+Af+Af+gX/gH/gP/4H/+R/w//8B//8f8P//Af7/D8D//wD4/wcA/H8AAP4DAOA/AAD/AQD4HwCA/wAA/A8A4H8AAP4HAPA/AAD/AQDwDwAAAAAAAAAA","aspect":0.66197},{"digit":"9","bits":"AAAAAAAAAAD+AQD4fwDA/x8A/v8D8P9/gP//B/j//4D//w/8j//Bf/Af/Af/wX/wH/wH/8F/8B/8z//B//8f+P//gf//H/D//wD//w/A//8A+P8PAMB/AAD+B/j/P8D//wP8/x/A//8B/P8PwP8/APz/AQD+AwAAAAAAAAAA","aspect":0.69565},{"digit":"9","bits":"AAAAAAAAAAD/AwD8/wDg/x8A//8D+P9/gP//B/z//8D//A/8h//Bf/Af/AP/wT/wH/wH/8F/+B/87//B//8f/P//gf//H/j//wH//x/g//8A+P8PAID/AAD8DwD4fwD//wfw/z8A//8B8P8fAP9/APD/AwD/DwAAAAAAAAAA","aspect":0.69118},{"digit":"9","bits":"AAAAAAAAAAD/AwD8/wDg/x8A//8D+P8/gP//B/z/f8D//A/8h//AP/gP/AP/wX/wH/yH/8H//B/8///B//8f+P//gf//H/D//wH+/x/A//8B8PcfAID/AAD8DwD8/wD8/wfA/z8A/P8DwP8fAPx/AMD/AQD8AwAAAAAAAAAA","aspect":0.7}];

function decodeTemplateBits(encoded, length = 28 * 36) {
  const binary = atob(encoded);
  const bits = new Uint8Array(length);
  for (let index = 0; index < length; index += 1) bits[index] = (binary.charCodeAt(index >> 3) >> (index & 7)) & 1;
  return bits;
}

function buildTemplates() {
  if (templates) return templates;
  templates = EMBEDDED_TEMPLATES.map((entry) => {
    const bits = decodeTemplateBits(entry.bits);
    let ink = 0;
    for (let index = 0; index < bits.length; index += 1) ink += bits[index];
    return { digit: entry.digit, bits, dilated: dilate(bits, 28, 36, 2), width: 28, height: 36, ink, aspect: Number(entry.aspect) || 1, holes: analyzeHoles(bits, 28, 36) };
  });
  return templates;
}

function recognize(pixels, width, height) {
  const bounds = alphaBounds(pixels, width, height);
  if (!bounds) return { value: '', confidence: 0 };
  const segments = digitSegments(pixels, width, height, bounds);
  if (!segments.length) return { value: '', confidence: 0 };
  const availableTemplates = buildTemplates();
  let value = '';
  let confidence = 1;

  for (const [minX, maxX] of segments) {
    let minY = height;
    let maxY = -1;
    for (let y = bounds.minY; y <= bounds.maxY; y += 1) {
      for (let x = minX; x <= maxX; x += 1) {
        if (!isInk(pixels, (y * width + x) * 4)) continue;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxY < minY) continue;
    const sample = normalizedBitmap(pixels, width, height, { minX, maxX, minY, maxY });
    let best = null;
    let second = null;
    for (const template of availableTemplates) {
      const score = bitmapSimilarity(sample, template);
      if (!best || score > best.score) {
        second = best;
        best = { digit: template.digit, score };
      } else if (!second || score > second.score) {
        second = { digit: template.digit, score };
      }
    }
    if (!best) continue;
    value += best.digit;
    confidence = Math.min(confidence, Math.max(0, Math.min(1, best.score * 0.82 + Math.max(0, best.score - (second?.score || 0)) * 1.8)));
  }

  return { value: /^\d{1,4}$/.test(value) ? value : '', confidence };
}

self.addEventListener('message', (event) => {
  const message = event.data || {};
  if (message.type === 'warmup') {
    try {
      buildTemplates();
      self.postMessage({ type: 'ready' });
    } catch (error) {
      self.postMessage({ type: 'error', message: error?.message || 'Recognition worker could not start.' });
    }
    return;
  }
  if (message.type !== 'recognize') return;
  try {
    const pixels = new Uint8ClampedArray(message.pixels);
    const result = recognize(pixels, Number(message.width) || 0, Number(message.height) || 0);
    self.postMessage({ type: 'result', requestId: message.requestId, revision: message.revision, ...result });
  } catch (error) {
    self.postMessage({ type: 'error', requestId: message.requestId, revision: message.revision, message: error?.message || 'Recognition failed.' });
  }
});
