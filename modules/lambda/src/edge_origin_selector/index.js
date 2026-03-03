'use strict';

const crypto = require('crypto');

function score(clientKey, origin) {
  const hex = crypto
    .createHash('sha256')
    .update(`${clientKey}|${origin}`)
    .digest('hex')
    .slice(0, 16);
  return BigInt(`0x${hex}`);
}

function chooseOrigin(clientKey, origins) {
  let bestOrigin = origins[0];
  let bestScore = score(clientKey, bestOrigin);

  for (let i = 1; i < origins.length; i += 1) {
    const candidate = origins[i];
    const candidateScore = score(clientKey, candidate);
    if (candidateScore > bestScore) {
      bestOrigin = candidate;
      bestScore = candidateScore;
    }
  }

  return bestOrigin;
}

exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;

  try {
    const headerValue = request.origin?.custom?.customHeaders?.['x-origin-list']?.[0]?.value;
    if (!headerValue) throw new Error("Missing x-origin-list header.");

    const origins = headerValue.split(',').map(o => o.trim()).filter(Boolean);
    if (origins.length === 0) throw new Error("No valid origins in x-origin-list.");

    const xff = request.headers['x-forwarded-for']?.[0]?.value || '0.0.0.0';
    const clientIp = xff.split(',')[0].trim();
    // Use IP-only stickiness to avoid origin shifts when User-Agent changes.
    const clientKey = clientIp;

    const chosenOrigin = chooseOrigin(clientKey, origins);

    console.log(`Chosen Origin: ${chosenOrigin} for IP: ${clientIp}`);

    request.origin.custom.domainName = chosenOrigin;
    callback(null, request);
  } catch (err) {
    console.log('Lambda@Edge Error:', err.message);
    callback(null, request);
  }
};
