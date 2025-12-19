import { useSelector } from "react-redux";
import { useVisibleSide } from "./useVisibleSide";

export const useVisibleFace = (cardId) => {
    const visibleSide = useVisibleSide(cardId);
    return useSelector(state => {
        const card = state?.gameUi?.game?.cardById?.[cardId];
        if (!card) return null;

        // Handle both nested (sides.A) and flat (A) structures
        if (card.sides && typeof card.sides === 'object' && !Array.isArray(card.sides)) {
            return card.sides[visibleSide];
        } else {
            return card[visibleSide];
        }
    });
}