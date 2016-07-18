requires 'Unicode::Escape';
requires 'YAML::Any';
requires 'YAML::XS';

requires 'HTML::Form';

on test => sub {
	requires 'Test::Assert';
};
