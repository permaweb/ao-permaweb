module.exports = {
	parser: '@typescript-eslint/parser',
	plugins: ['import', '@typescript-eslint', 'simple-import-sort'],
	extends: [],
	rules: {
		'import/no-duplicates': 'error',
		'simple-import-sort/imports': 'error',
		'simple-import-sort/exports': 'error',
	},
	overrides: [
		{
			files: ['*.js', '*.jsx', '*.ts', '*.tsx'],
			rules: {
				'simple-import-sort/imports': [
					'error',
					{
						groups: [
							['^react', '^@?\\w'],
							['^@permaweb/aoconnect', '^@?\\w'],
							[
								'^(@|app)(/.*|$)',
								'^(@|assets)(/.*|$)',
								'^(@|clients)(/.*|$)',
								'^(@|components)(/.*|$)',
								'^(@|filters)(/.*|$)',
								'^(@|global)(/.*|$)',
								'^(@|helpers)(/.*|$)',
								'^(@|hooks)(/.*|$)',
								'^(@|navigation)(/.*|$)',
								'^(@|providers)(/.*|$)',
								'^(@|root)(/.*|$)',
								'^(@|routes)(/.*|$)',
								'^(@|search)(/.*|$)',
								'^(@|store)(/.*|$)',
								'^(@|views)(/.*|$)',
								'^(@|wallet)(/.*|$)',
								'^(@|workers)(/.*|$)',
								'^(@|wrappers)(/.*|$)',
							],
							['^\\u0000'],
							['^\\.\\.(?!/?$)', '^\\.\\./?$'],
							['^\\./(?=.*/)(?!/?$)', '^\\.(?!/?$)', '^\\./?$'],
						],
					},
				],
			},
		},
	],
};
