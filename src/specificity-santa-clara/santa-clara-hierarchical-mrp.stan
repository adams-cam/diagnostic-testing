data {
  int<lower = 0> N;  // number of tests in the sample (3330 for Santa Clara)
  int<lower = 0, upper = 1> y[N];  // 1 if positive, 0 if negative
  vector<lower = -0.5, upper = 0.5>[N] male;  // -0.5 if female, 0.5 if male
  int<lower = 1, upper = 4> eth[N];  // 1=white, 2=asian, 3=hispanic, 4=other
  int<lower = 1, upper = 4> age[N];  // 1=0-4, 2=5-18, 3=19-64, 4=65+
  int<lower = 0> N_zip;  // number of zip codes (58 in this case)
  int<lower = 1, upper = N_zip> zip[N];  // zip codes 1 through 58
  vector[N_zip] x_zip;  // predictors at the zip code level
  int<lower = 0> J_spec;
  int<lower = 0> y_spec [J_spec];
  int<lower = 0> n_spec [J_spec];
  int<lower = 0> J_sens;
  int<lower = 0> y_sens [J_sens];
  int<lower = 0> n_sens [J_sens];
  int<lower = 0> J;  // number of population cells, J = 2*4*4*58
  vector<lower = 0>[J] N_pop;  // population sizes for poststratification
  real intercept_prior_mean;
  real<lower = 0> intercept_prior_scale;
  real<lower = 0> coef_prior_scale;
  real<lower = 0> logit_spec_prior_scale;
  real<lower = 0> logit_sens_prior_scale;
}
parameters {
  real mu_logit_spec;
  real mu_logit_sens;
  real<lower = 0> sigma_logit_spec;
  real<lower = 0> sigma_logit_sens;
  vector<offset = mu_logit_spec, multiplier = sigma_logit_spec>[J_spec] logit_spec;
  vector<offset = mu_logit_sens, multiplier = sigma_logit_sens>[J_sens] logit_sens;
  vector[3] b;  // intercept, coef for male, and coef for x_zip
  real<lower = 0> sigma_eth;
  real<lower = 0> sigma_age;
  real<lower = 0> sigma_zip;
  vector<multiplier = sigma_eth>[4] a_eth;  // varying intercepts for ethnicity
  vector<multiplier = sigma_age>[4] a_age;  // varying intercepts for age category
  vector<multiplier = sigma_zip>[N_zip] a_zip;  // varying intercepts for zip code
}
transformed parameters {
  vector[J_spec] spec = inv_logit(logit_spec);
  vector[J_sens] sens = inv_logit(logit_sens);
}
model {
  vector[N] p = inv_logit(b[1]
                          + b[2] * male
                          + b[3] * x_zip[zip]
                          + a_eth[eth]
                          + a_age[age]
                          + a_zip[zip]);
  vector[N] p_sample = p * sens[1] + (1 - p) * (1 - spec[1]);
  y ~ bernoulli(p_sample);
  y_spec ~ binomial(n_spec, spec);
  y_sens ~ binomial(n_sens, sens);
  logit_spec ~ normal(mu_logit_spec, sigma_logit_spec);
  logit_sens ~ normal(mu_logit_sens, sigma_logit_sens);
  sigma_logit_spec ~ normal(0, logit_spec_prior_scale);
  sigma_logit_sens ~ normal(0, logit_sens_prior_scale);
  a_eth ~ normal(0, sigma_eth);
  a_age ~ normal(0, sigma_age);
  a_zip ~ normal(0, sigma_zip);
  // prior on centered intercept
  b[1] + b[2] * mean(male) + b[3] * mean(x_zip)
      ~ normal(intercept_prior_mean, intercept_prior_scale);
  b[2]  ~ normal(0, coef_prior_scale);
  sigma_eth ~ normal(0, coef_prior_scale);
  sigma_age ~ normal(0, coef_prior_scale);
  sigma_zip ~ normal(0, coef_prior_scale);
  b[3] ~ normal(0, coef_prior_scale / sd(x_zip));  // prior on scaled coefficient
}
generated quantities {
  real p_avg;
  vector[J] p_pop;  // population prevalence in the J poststratification cells
  int count;
  count = 1;
  for (i_zip in 1:N_zip) {
    for (i_age in 1:4) {
      for (i_eth in 1:4) {
        for (x_male in { -0.5, 0.5 }) {
          p_pop[count] = inv_logit(b[1]
                                   + b[2] * x_male
                                   + b[3] * x_zip[i_zip]
                                   + a_eth[i_eth]
                                   + a_age[i_age]
                                   + a_zip[i_zip]);
          count += 1;
        }
      }
    }
  }
  p_avg = sum(N_pop .* p_pop) / sum(N_pop);
}
