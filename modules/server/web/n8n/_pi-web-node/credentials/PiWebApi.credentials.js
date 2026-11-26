'use strict';

/**
 * Connection to a Pi Web instance.
 *
 * Pi Web answers unauthenticated unless it runs with PI_WEB_PASSWORD set, in
 * which case every /api route takes the password in HTTP Basic with any
 * username (see lib/web-auth.ts upstream), which is what the node sends.
 *
 * The hostname must also be one Pi Web accepts: loopback, an IP literal, or an
 * entry of PI_WEB_ALLOWED_HOSTS on the host serving it.
 */
class PiWebApi {
	constructor() {
		this.name = 'piWebApi';
		this.displayName = 'Pi Web API';
		this.icon = 'fa:network-wired';
		this.description = 'Base URL and password of a Pi Web server';
		this.properties = [
			{
				displayName: 'Base URL',
				name: 'baseUrl',
				type: 'string',
				default: 'https://pi.brix0.wilkins.pl.eu.org',
				placeholder: 'https://pi.example.org',
				description: 'Address of the Pi Web instance, without a trailing slash',
				required: true,
			},
			{
				displayName: 'Password',
				name: 'password',
				type: 'password',
				default: '',
				description:
					'PI_WEB_PASSWORD of that instance. Left empty, requests go out unauthenticated, which is all a Pi Web without a password accepts anyway',
			},
		];
	}
}

module.exports = { PiWebApi };
