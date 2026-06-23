# Migration And Practices

## v3 to v4 Migration Checklist

- [ ] Replace `tailwind.config.ts` with CSS `@theme` block
- [ ] Change `@tailwind base/components/utilities` to `@import "tailwindcss"`
- [ ] Move color definitions to `@theme { --color-*: value }`
- [ ] Replace `darkMode: "class"` with `@custom-variant dark`
- [ ] Move `@keyframes` inside `@theme` blocks (ensures keyframes output with theme)
- [ ] Replace `require("tailwindcss-animate")` with native CSS animations
- [ ] Update `h-10 w-10` to `size-10` (new utility)
- [ ] Remove `forwardRef` (React 19 passes ref as prop)
- [ ] Consider OKLCH colors for better color perception
- [ ] Replace custom plugins with `@utility` directives

## Best Practices

### Do's

- **Use `@theme` blocks** - CSS-first configuration is v4's core pattern
- **Use OKLCH colors** - Better perceptual uniformity than HSL
- **Compose with CVA** - Type-safe variants
- **Use semantic tokens** - `bg-primary` not `bg-blue-500`
- **Use `size-*`** - New shorthand for `w-* h-*`
- **Add accessibility** - ARIA attributes, focus states

### Don'ts

- **Don't use `tailwind.config.ts`** - Use CSS `@theme` instead
- **Don't use `@tailwind` directives** - Use `@import "tailwindcss"`
- **Don't use `forwardRef`** - React 19 passes ref as prop
- **Don't use arbitrary values** - Extend `@theme` instead
- **Don't hardcode colors** - Use semantic tokens
- **Don't forget dark mode** - Test both themes

## Resources

- [Tailwind CSS v4 Documentation](https://tailwindcss.com/docs)
- [Tailwind v4 Beta Announcement](https://tailwindcss.com/blog/tailwindcss-v4-beta)
- [CVA Documentation](https://cva.style/docs)
- [shadcn/ui](https://ui.shadcn.com/)
- [Radix Primitives](https://www.radix-ui.com/primitives)
