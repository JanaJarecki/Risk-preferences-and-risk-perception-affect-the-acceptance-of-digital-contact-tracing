pacman::p_load(data.table, ggplot2, themejj, ggthemes, patchwork)
source("setup_figures.R")

# Load data -------------------------------------------------------------------
d <- fread("../../data/processed/data.csv")

# Prepare --------------------------------------------------------------------
d[, gender := fcase(
  female == 0, " Male",
  female == 1, "Female",
  female == 2, NA_character_)]
d[, age_bin := cut(age, 6, dig.lab=2)]
d[education <= 2, education := 2]
d[, education_f := factor(education, labels = c("No/Obligatory", "Vocational", "Higher", "College", "University"), ordered = T)]

d[, safety_mask := safety_mask/100]
to_plot <- c("mhealth_score", "policy_score", "compreh_score", "accept_index", "comply_index")
labels <- c("Mental Health", "Policy Support", "Comprehension", "Acceptance", "Compliance")

plot_it <- function(xstring, xtitle) {
  p1 <- ggplot(melt(d, id = c("id", xstring), measure = to_plot, na.rm=TRUE)[!is.na(get(xstring))],
    aes_string(xstring, "value")) +
    geom_tufteboxplot(median.type = "line", hoffset = 0, width = 5, fatten = 10) +
    stat_summary(geom = "crossbar", width = .9, fatten=1.3, color="white", fun.data = function(x){c(y=median(x), ymin=median(x), ymax=median(x))}) +
    facet_wrap(~factor(variable, levels = to_plot, label = labels), nrow=1, scales = "free_y") +
    guides(fill="none") +
    scale_x_discrete(expand = c(0,0)) +
    theme(
      #aspect.ratio = .8,
      axis.text.x = element_text(angle = 90, vjust = .5, hjust = 1),
      axis.ticks.x = element_blank(),
      plot.margin = margin(c(0,0,0,0), unit = "lines")) +
    xlab(xtitle) +
    ylab("Value")

  p2 <- ggplot(d[!is.na(get(xstring)), .N, by = xstring], aes_string(x = xstring, y = "N")) +
    geom_bar(stat = "identity", fill = "grey80", color = NA, width = .5, position = position_dodge(width=0.6)) +
    scale_x_discrete(name = "", expand = c(.4,0)) +
    scale_y_continuous(expand = c(0,0)) +
    theme(
      aspect.ratio = .8,
      axis.text.x = element_text(angle = 90, vjust = .5, hjust = 1),
      axis.ticks.x = element_blank(),
      plot.margin = margin(c(b=1.3,0,0,0), unit = "lines"))
  (p1 | p2) 
}


(plot_it("age_bin", "Age bin") + plot_layout(tag_level = "new")) /
(plot_it("gender", "") + plot_layout(tag_level = 'new')) /
#(plot_it("education_f", "Education") + plot_layout(tag_level = "new")) +
plot_layout(nrow = 2) +
plot_annotation(tag_levels = c("A", "1")) &
theme(plot.margin = margin(0.2, unit = "lines"))

ggsave("../figures/fig_descriptive.pdf", w = 9.5, h = 3.5, scale = 1.4)